# frozen_string_literal: true

module Commodore
  # A small Commodore BASIC V2: enough of it to type in the classics
  # (10 PRINT CHR$(205.5+RND(1)); : GOTO 10) and to LIST and RUN the
  # programs the door loads. Numbers are floats, strings end in $, and only
  # the first two letters of a name count, as on the real machine.
  #
  # The screen is a Struct of callables, so the interpreter never touches
  # the telnet line itself:
  #   write.(text)  print text at the cursor (it wraps at 40 columns)
  #   newline.()    move to the next line
  #   column.()     the cursor column, 0-based
  #   cls.()        clear the screen
  #   readline.()   one line from the caller (INPUT), nil on hang-up
  #   stop?.()      true when the caller pressed a key: RUN/STOP
  class Basic
    Screen = Struct.new(:write, :newline, :column, :cls, :readline, :stop?, keyword_init: true)

    class Error < StandardError; end
    class Break < StandardError; end
    class Reset < StandardError; end

    KEYWORDS = %w[
      PRINT GOTO GOSUB RETURN IF THEN FOR TO STEP NEXT END STOP REM LET INPUT
      POKE PEEK CLR LIST RUN NEW SYS AND OR NOT RND INT ABS SGN SQR SIN COS TAN
      LEN STR$ VAL CHR$ ASC LEFT$ RIGHT$ MID$
    ].sort_by { |k| -k.length }.freeze

    FUNCTIONS = %w[RND INT ABS SGN SQR SIN COS TAN LEN STR$ VAL CHR$ ASC LEFT$ RIGHT$ MID$ PEEK].freeze

    MAX_STEPS = 2_000_000

    Token = Struct.new(:type, :value)

    attr_reader :lines

    def initialize(screen, reset_address: nil)
      @screen        = screen
      @reset_address = reset_address
      @lines         = []
      @memory        = {}
      @token_cache   = {}
      clear_variables
    end

    # One line typed at READY. A line number stores (or, alone, deletes) a
    # program line; anything else runs at once. Raises Reset on SYS to the
    # reset vector.
    def enter(text)
      text = crunch(text.strip)
      return if text.empty?

      if (m = text.match(/\A(\d+)\s?(.*)\z/))
        store(m[1].to_i, m[2])
        return
      end
      run_immediate(text)
    end

    # Replaces the program, e.g. with a loaded directory (whose line numbers
    # repeat, as on the real machine).
    def load(lines)
      @lines = lines.map { |n, t| [n, t] }
      @token_cache = {}
      clear_variables
    end

    private

    # ── program store ──────────────────────────────────────────────────────

    def store(number, text)
      raise Error, 'SYNTAX' if number > 63_999

      @lines.reject! { |n, _| n == number }
      @lines << [number, text] unless text.strip.empty?
      @lines.sort_by!(&:first)
      @token_cache = {}
      clear_variables
    end

    def clear_variables
      @vars       = {}
      @for_stack  = []
      @gosub      = []
    end

    # Upper case outside string literals, like the keyboard of the machine.
    def crunch(text)
      text.split(/("[^"]*"?)/).map { |part| part.start_with?('"') ? part : part.upcase }.join
    end

    # ── running ────────────────────────────────────────────────────────────

    def run_immediate(text)
      @line_index = nil
      @toks       = tokenize(text)
      @pos        = 0
      execute
    rescue Error => e
      report(e.message)
    rescue Break
      @screen.newline.call unless @screen.column.call.zero?
      @screen.write.call("BREAK#{" IN #{@lines[@line_index][0]}" if @line_index}")
      @screen.newline.call
    end

    def report(message)
      @screen.newline.call unless @screen.column.call.zero?
      where = @line_index ? " IN #{@lines[@line_index][0]}" : ''
      @screen.write.call("?#{message}  ERROR#{where}")
      @screen.newline.call
    end

    # Runs statements from @toks/@pos; in program mode it moves on to the
    # next line at the end of each one.
    def execute
      @steps = 0
      loop do
        statement_loop
        return if @halted

        return if @line_index.nil?

        @line_index += 1
        return if @line_index >= @lines.size

        enter_line(@line_index, 0)
      end
    ensure
      @halted = false
    end

    def statement_loop
      while @pos < @toks.size
        @steps += 1
        raise Break if @steps > MAX_STEPS
        raise Break if (@steps % 500).zero? && @screen.stop?.call

        tok = @toks[@pos]
        if tok.type == :op && tok.value == ':'
          @pos += 1
          next
        end
        statement
        return if @halted
      end
    end

    def enter_line(index, pos)
      @line_index = index
      number, text = @lines[index]
      @toks  = (@token_cache[[index, number]] ||= tokenize(text))
      @pos   = pos
      @moved = true
    end

    def jump_to_line(number)
      index = @lines.index { |n, _| n == number }
      raise Error, "UNDEF'D STATEMENT" unless index

      enter_line(index, 0)
    end

    # ── statements ─────────────────────────────────────────────────────────

    # A jump, or an IF that goes on with the rest of its line, leaves the
    # cursor where no ':' has to follow.
    def statement
      @moved = false
      tok = advance
      case tok.type
      when :kw
        case tok.value
        when 'PRINT'  then st_print
        when 'GOTO'   then jump_to_line(line_number)
        when 'GOSUB'  then st_gosub
        when 'RETURN' then st_return
        when 'IF'     then st_if
        when 'FOR'    then st_for
        when 'NEXT'   then st_next
        when 'END'    then @halted = true
        when 'STOP'   then raise Break
        when 'REM'    then @pos = @toks.size
        when 'LET'    then st_let(advance)
        when 'INPUT'  then st_input
        when 'POKE'   then st_poke
        when 'CLR'    then clear_variables
        when 'LIST'   then st_list
        when 'RUN'    then st_run
        when 'NEW'    then load([]); @halted = true
        when 'SYS'    then st_sys
        else raise Error, 'SYNTAX'
        end
      when :var then st_let(tok)
      else raise Error, 'SYNTAX'
      end
      expect_end unless @moved
    end

    def expect_end
      return if @halted || @pos >= @toks.size
      return if @toks[@pos].type == :op && @toks[@pos].value == ':'

      raise Error, 'SYNTAX'
    end

    def st_print
      newline = true
      until statement_end?
        tok = @toks[@pos]
        if tok.type == :op && tok.value == ';'
          @pos += 1
          newline = false
        elsif tok.type == :op && tok.value == ','
          @pos += 1
          @screen.write.call(' ' * (10 - (@screen.column.call % 10)))
          newline = false
        else
          value = expression
          @screen.write.call(value.is_a?(String) ? value : format_number(value))
          newline = true
        end
      end
      @screen.newline.call if newline
      raise Break if @screen.stop?.call
    end

    def st_gosub
      target = line_number
      @gosub.push([@line_index, @pos, @toks])
      raise Error, 'OUT OF MEMORY' if @gosub.size > 24

      jump_to_line(target)
    end

    def st_return
      raise Error, 'RETURN WITHOUT GOSUB' if @gosub.empty?

      @line_index, @pos, @toks = @gosub.pop
      @moved = true
    end

    def st_if
      condition = expression
      tok = advance
      raise Error, 'SYNTAX' unless tok.type == :kw && %w[THEN GOTO].include?(tok.value)

      if truthy?(condition)
        if tok.value == 'GOTO' || @toks[@pos]&.type == :num
          jump_to_line(line_number)
        else
          @moved = true
        end
      else
        @pos = @toks.size
      end
    end

    def st_for
      var = advance
      raise Error, 'SYNTAX' unless var.type == :var && !var.value.end_with?('$')

      expect_op('=')
      @vars[var.value] = number(expression)
      expect_kw('TO')
      limit = number(expression)
      step = 1.0
      if @toks[@pos]&.type == :kw && @toks[@pos].value == 'STEP'
        @pos += 1
        step = number(expression)
      end
      @for_stack.reject! { |f| f[:var] == var.value }
      @for_stack.push(var: var.value, limit: limit, step: step, line: @line_index, pos: @pos, toks: @toks)
    end

    def st_next
      names = []
      if @toks[@pos]&.type == :var
        names << advance.value
        while @toks[@pos]&.type == :op && @toks[@pos].value == ','
          @pos += 1
          names << advance.value
        end
      end
      names << nil if names.empty?
      names.each do |name|
        frame_index = name ? @for_stack.rindex { |f| f[:var] == name } : @for_stack.size - 1
        raise Error, 'NEXT WITHOUT FOR' if frame_index.nil? || frame_index.negative?

        @for_stack.slice!((frame_index + 1)..)
        frame = @for_stack.last
        value = @vars[frame[:var]] = @vars.fetch(frame[:var], 0.0) + frame[:step]
        done = frame[:step].negative? ? value < frame[:limit] : value > frame[:limit]
        if done
          @for_stack.pop
          next
        end

        @line_index = frame[:line]
        @toks       = frame[:toks]
        @pos        = frame[:pos]
        @moved      = true
        break
      end
    end

    def st_let(var)
      raise Error, 'SYNTAX' unless var.type == :var

      expect_op('=')
      assign(var.value, expression)
    end

    def st_input
      prompt = ''
      if @toks[@pos]&.type == :str
        prompt = advance.value
        expect_op(';')
      end
      names = [advance]
      while @toks[@pos]&.type == :op && @toks[@pos].value == ','
        @pos += 1
        names << advance
      end
      raise Error, 'SYNTAX' unless names.all? { |t| t&.type == :var }

      loop do
        @screen.write.call("#{prompt}? ")
        answer = @screen.readline.call
        raise Break if answer.nil?

        values = answer.split(',', -1).map(&:strip)
        if names.each_with_index.all? { |t, i| t.value.end_with?('$') || numeric?(values[i]) }
          names.each_with_index do |t, i|
            assign(t.value, t.value.end_with?('$') ? values[i].to_s : values[i].to_f)
          end
          break
        end
        @screen.write.call('?REDO FROM START')
        @screen.newline.call
      end
    end

    def st_poke
      address = integer(expression, 0..65_535)
      expect_op(',')
      @memory[address] = integer(expression, 0..255)
    end

    def st_list
      from = 0
      to   = 63_999
      from = to = advance.value.to_i if @toks[@pos]&.type == :num
      if @toks[@pos]&.type == :op && @toks[@pos].value == '-'
        @pos += 1
        to = @toks[@pos]&.type == :num ? advance.value.to_i : 63_999
      end
      @lines.each do |n, text|
        next unless n.between?(from, to)
        raise Break if @screen.stop?.call

        @screen.write.call("#{n} #{text}")
        @screen.newline.call
      end
      @halted = true if @line_index.nil?
    end

    def st_run
      start = @toks[@pos]&.type == :num ? advance.value.to_i : nil
      clear_variables
      return @halted = true if @lines.empty?

      start ? jump_to_line(start) : enter_line(0, 0)
    end

    def st_sys
      address = integer(expression, 0..65_535)
      raise Reset if address == @reset_address
    end

    # ── expressions ────────────────────────────────────────────────────────

    def expression = expr_or

    def expr_or
      left = expr_and
      while kw?('OR')
        @pos += 1
        left = (integer(left, -32_768..32_767) | integer(expr_and, -32_768..32_767)).to_f
      end
      left
    end

    def expr_and
      left = expr_not
      while kw?('AND')
        @pos += 1
        left = (integer(left, -32_768..32_767) & integer(expr_not, -32_768..32_767)).to_f
      end
      left
    end

    def expr_not
      if kw?('NOT')
        @pos += 1
        return (~integer(expr_not, -32_768..32_767)).to_f
      end
      expr_relation
    end

    def expr_relation
      left = expr_add
      while (op = relation_op)
        right = expr_add
        raise Error, 'TYPE MISMATCH' unless left.instance_of?(right.class)

        result = case op
                 when '='  then left == right
                 when '<>' then left != right
                 when '<'  then left < right
                 when '>'  then left > right
                 when '<=' then left <= right
                 when '>=' then left >= right
                 end
        left = result ? -1.0 : 0.0
      end
      left
    end

    def relation_op
      tok = @toks[@pos]
      return nil unless tok&.type == :op && %w[= <> < > <= >=].include?(tok.value)

      @pos += 1
      tok.value
    end

    def expr_add
      left = expr_mul
      while (tok = @toks[@pos]) && tok.type == :op && %w[+ -].include?(tok.value)
        @pos += 1
        right = expr_mul
        if tok.value == '+' && left.is_a?(String) && right.is_a?(String)
          left += right
          raise Error, 'STRING TOO LONG' if left.length > 255
        else
          left = tok.value == '+' ? number(left) + number(right) : number(left) - number(right)
        end
      end
      left
    end

    def expr_mul
      left = expr_unary
      while (tok = @toks[@pos]) && tok.type == :op && %w[* /].include?(tok.value)
        @pos += 1
        right = number(expr_unary)
        if tok.value == '*'
          left = number(left) * right
        else
          raise Error, 'DIVISION BY ZERO' if right.zero?

          left = number(left) / right
        end
      end
      left
    end

    def expr_unary
      tok = @toks[@pos]
      if tok&.type == :op && %w[- +].include?(tok.value)
        @pos += 1
        value = number(expr_unary)
        return tok.value == '-' ? -value : value
      end
      expr_power
    end

    def expr_power
      left = primary
      while (tok = @toks[@pos]) && tok.type == :op && tok.value == '^'
        @pos += 1
        left = number(left)**number(primary)
        raise Error, 'ILLEGAL QUANTITY' if left.is_a?(Complex)
      end
      left
    end

    def primary
      tok = advance
      raise Error, 'SYNTAX' unless tok

      case tok.type
      when :num, :str then tok.value
      when :var then @vars.fetch(tok.value) { tok.value.end_with?('$') ? '' : 0.0 }
      when :op
        raise Error, 'SYNTAX' unless tok.value == '('

        value = expression
        expect_op(')')
        value
      when :kw
        raise Error, 'SYNTAX' unless FUNCTIONS.include?(tok.value)

        call_function(tok.value)
      end
    end

    def call_function(name)
      expect_op('(')
      args = [expression]
      while @toks[@pos]&.type == :op && @toks[@pos].value == ','
        @pos += 1
        args << expression
      end
      expect_op(')')
      a = args[0]
      case name
      when 'RND'   then rand
      when 'INT'   then number(a).floor.to_f
      when 'ABS'   then number(a).abs
      when 'SGN'   then (number(a) <=> 0).to_f
      when 'SQR'   then number(a).negative? ? raise(Error, 'ILLEGAL QUANTITY') : Math.sqrt(a)
      when 'SIN'   then Math.sin(number(a))
      when 'COS'   then Math.cos(number(a))
      when 'TAN'   then Math.tan(number(a))
      when 'LEN'   then string(a).length.to_f
      when 'STR$'  then format_number(number(a)).rstrip
      when 'VAL'   then string(a).strip[/\A[-+]?(\d+\.?\d*|\.\d+)(E[-+]?\d+)?/i].to_f
      when 'CHR$'  then petscii(integer(a, 0..255))
      when 'ASC'   then string(a).empty? ? raise(Error, 'ILLEGAL QUANTITY') : string(a).ord.to_f
      when 'LEFT$' then string(a)[0, integer(args[1], 0..255)]
      when 'RIGHT$'
        n = integer(args[1], 0..255)
        n.zero? ? '' : string(a)[-n..] || string(a)
      when 'MID$'
        start = integer(args[1], 1..255) - 1
        string(a)[start, args[2] ? integer(args[2], 0..255) : 255] || ''
      when 'PEEK' then @memory.fetch(integer(a, 0..65_535), 0).to_f
      end
    end

    # The PETSCII characters a terminal can show: 147 clears the screen,
    # 205/206 are the two diagonals of the maze, 13 is a new line.
    def petscii(code)
      case code
      when 13       then "\n"
      when 147      then "\f"
      when 205, 109 then '╲'
      when 206, 110 then '╱'
      when 32..126  then code.chr
      else ''
      end
    end

    # ── helpers ────────────────────────────────────────────────────────────

    def assign(name, value)
      raise Error, 'TYPE MISMATCH' unless name.end_with?('$') == value.is_a?(String)

      @vars[name] = value
    end

    def numeric?(text) = text.to_s.match?(/\A[-+]?(\d+\.?\d*|\.\d+)(E[-+]?\d+)?\z/i)

    def truthy?(value) = value.is_a?(String) ? !value.empty? : !value.zero?

    def number(value)
      raise Error, 'TYPE MISMATCH' if value.is_a?(String)

      value.to_f
    end

    def string(value)
      raise Error, 'TYPE MISMATCH' unless value.is_a?(String)

      value
    end

    def integer(value, range)
      n = number(value).floor
      raise Error, 'ILLEGAL QUANTITY' unless range.cover?(n)

      n
    end

    def line_number
      tok = advance
      raise Error, 'SYNTAX' unless tok&.type == :num

      tok.value.to_i
    end

    def statement_end?
      @pos >= @toks.size || (@toks[@pos].type == :op && @toks[@pos].value == ':')
    end

    def kw?(word) = @toks[@pos]&.type == :kw && @toks[@pos].value == word

    def advance
      tok = @toks[@pos]
      @pos += 1 if tok
      tok
    end

    def expect_op(op)
      tok = advance
      raise Error, 'SYNTAX' unless tok&.type == :op && tok.value == op
    end

    def expect_kw(word)
      tok = advance
      raise Error, 'SYNTAX' unless tok&.type == :kw && tok.value == word
    end

    # C64 numbers: integers plainly, the rest with nine digits and no leading
    # zero; a space before positives and after every number.
    def format_number(value)
      text = if value == value.floor && value.abs < 1e9
               value.to_i.to_s
             else
               format('%.9g', value).sub(/\A(-?)0\./, '\1.').upcase
             end
      value.negative? ? "#{text} " : " #{text} "
    end

    # ── tokenizer ──────────────────────────────────────────────────────────

    # Keywords are found anywhere outside strings, even inside a name: TOTAL
    # reads as TO TAL, the way the machine's own cruncher read it.
    def tokenize(text)
      tokens = []
      i = 0
      while i < text.length
        ch = text[i]
        if ch == ' '
          i += 1
        elsif ch == '"'
          close = text.index('"', i + 1) || text.length
          tokens << Token.new(:str, text[(i + 1)...close])
          i = close + 1
        elsif ch == '?'
          tokens << Token.new(:kw, 'PRINT')
          i += 1
        elsif ch.match?(/[0-9.]/)
          m = text[i..].match(/\A(\d*\.?\d*)(E[-+]?\d+)?/)
          raise Error, 'SYNTAX' if m[0] == '.'

          tokens << Token.new(:num, m[0].to_f)
          i += m[0].length
        elsif (kw = keyword_at(text, i))
          tokens << Token.new(:kw, kw)
          i += kw.length
          if kw == 'REM'
            tokens << Token.new(:rem, text[i..])
            break
          end
        elsif ch.match?(/[A-Z]/)
          start = i
          i += 1
          i += 1 while i < text.length && text[i].match?(/[A-Z0-9]/) && !keyword_at(text, i)
          name = text[start...i]
          if text[i] == '$'
            i += 1
            tokens << Token.new(:var, "#{name[0, 2]}$")
          else
            tokens << Token.new(:var, name[0, 2])
          end
        elsif (op = text[i, 2]) && %w[<> <= >=].include?(op)
          tokens << Token.new(:op, op)
          i += 2
        elsif '+-*/^()=<>,;:'.include?(ch)
          tokens << Token.new(:op, ch)
          i += 1
        else
          raise Error, 'SYNTAX'
        end
      end
      tokens
    end

    def keyword_at(text, i)
      KEYWORDS.find { |kw| text[i, kw.length] == kw }
    end
  end
end
