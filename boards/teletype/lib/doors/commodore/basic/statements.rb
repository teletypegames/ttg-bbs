# frozen_string_literal: true

module Commodore
  class Basic
    # The statements of BASIC V2, one method each: the keyword names the
    # method in STATEMENTS. A jump, or an IF that goes on with the rest of
    # its line, sets @moved: the cursor is then where no ':' has to follow.
    module Statements
      STATEMENTS = {
        'PRINT' => :st_print, 'GOTO' => :st_goto, 'GOSUB' => :st_gosub, 'RETURN' => :st_return,
        'IF' => :st_if, 'FOR' => :st_for, 'NEXT' => :st_next, 'END' => :st_end, 'STOP' => :st_stop,
        'REM' => :st_rem, 'LET' => :st_let_keyword, 'INPUT' => :st_input, 'POKE' => :st_poke,
        'CLR' => :clear_variables, 'LIST' => :st_list, 'RUN' => :st_run, 'NEW' => :st_new, 'SYS' => :st_sys
      }.freeze

      private

      def statement
        @moved = false
        tok = advance
        if tok.type == :var then st_let(tok)
        elsif tok.type == :kw && STATEMENTS.key?(tok.value) then send(STATEMENTS[tok.value])
        else raise Error, 'SYNTAX'
        end
        expect_end unless @moved
      end

      def expect_end
        return if @halted || @pos >= @toks.size
        return if op?(@toks[@pos], ':')

        raise Error, 'SYNTAX'
      end

      def st_goto = jump_to_line(line_number)
      def st_end  = @halted = true
      def st_stop = raise(Break)
      def st_rem  = @pos = @toks.size
      def st_let_keyword = st_let(advance)

      def st_new
        load([])
        @halted = true
      end

      def st_print
        newline = true
        newline = printed_value?(@toks[@pos]) until statement_end?
        @screen.newline.call if newline
        raise Break if @screen.stop?.call
      end

      # Prints one item of a PRINT (a value, or the ; and , between them);
      # true for a value: the line ends after it unless a ; or , follows.
      def printed_value?(tok)
        if op?(tok, ';')
          @pos += 1
          false
        elsif op?(tok, ',')
          @pos += 1
          @screen.write.call(' ' * (10 - (@screen.column.call % 10)))
          false
        else
          value = expression
          @screen.write.call(value.is_a?(String) ? value : format_number(value))
          true
        end
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

        if !truthy?(condition) then @pos = @toks.size
        elsif tok.value == 'GOTO' || @toks[@pos]&.type == :num then jump_to_line(line_number)
        else @moved = true
        end
      end

      def st_for
        var = advance
        raise Error, 'SYNTAX' unless var.type == :var && !var.value.end_with?('$')

        expect_op('=')
        @vars[var.value] = number(expression)
        expect_kw('TO')
        limit = number(expression)
        step  = for_step
        @for_stack.reject! { |f| f[:var] == var.value }
        @for_stack.push(var: var.value, limit: limit, step: step, line: @line_index, pos: @pos, toks: @toks)
      end

      def for_step
        return 1.0 unless kw?('STEP')

        @pos += 1
        number(expression)
      end

      # NEXT, NEXT I or NEXT J,I: the first loop that goes on jumps back.
      def st_next
        names = @toks[@pos]&.type == :var ? comma_list { advance.value } : [nil]
        names.each { |name| break if loop_again?(name) }
      end

      # Steps the loop of +name+ (the innermost one for nil); true when it
      # goes on, false when it is over.
      def loop_again?(name)
        frame = for_frame(name)
        value = @vars[frame[:var]] = @vars.fetch(frame[:var], 0.0) + frame[:step]
        if loop_done?(frame, value)
          @for_stack.pop
          return false
        end

        resume(frame)
        true
      end

      # The loop of +name+, the loops inside it dropped.
      def for_frame(name)
        index = name ? @for_stack.rindex { |f| f[:var] == name } : @for_stack.size - 1
        raise Error, 'NEXT WITHOUT FOR' if index.nil? || index.negative?

        @for_stack.slice!((index + 1)..)
        @for_stack.last
      end

      def loop_done?(frame, value) = frame[:step].negative? ? value < frame[:limit] : value > frame[:limit]

      def resume(frame)
        @line_index = frame[:line]
        @toks       = frame[:toks]
        @pos        = frame[:pos]
        @moved      = true
      end

      def st_let(var)
        raise Error, 'SYNTAX' unless var.type == :var

        expect_op('=')
        assign(var.value, expression)
      end

      def st_input
        prompt = input_prompt
        names  = input_names
        until (values = input_values(prompt, names))
          @screen.write.call('?REDO FROM START')
          @screen.newline.call
        end
        names.zip(values).each { |name, value| assign(name, name.end_with?('$') ? value.to_s : value.to_f) }
      end

      def input_prompt
        return '' unless @toks[@pos]&.type == :str

        prompt = advance.value
        expect_op(';')
        prompt
      end

      def input_names
        names = comma_list { advance }
        raise Error, 'SYNTAX' unless names.all? { |t| t&.type == :var }

        names.map(&:value)
      end

      # The caller's answer split at the commas; nil when a number is not one.
      def input_values(prompt, names)
        @screen.write.call("#{prompt}? ")
        answer = @screen.readline.call
        raise Break if answer.nil?

        values = answer.split(',', -1).map(&:strip)
        values if names.each_with_index.all? { |name, i| name.end_with?('$') || numeric?(values[i]) }
      end

      def st_poke
        address = integer(expression, 0..65_535)
        expect_op(',')
        @memory[address] = integer(expression, 0..255)
      end

      def st_list
        from, to = list_range
        @lines.each { |n, text| list_line(n, text) if n.between?(from, to) }
        @halted = true if @line_index.nil?
      end

      # LIST, LIST 10, LIST 10-, LIST -20, LIST 10-20.
      def list_range
        from = 0
        to   = 63_999
        from = to = advance.value.to_i if @toks[@pos]&.type == :num
        return [from, to] unless op?(@toks[@pos], '-')

        @pos += 1
        [from, @toks[@pos]&.type == :num ? advance.value.to_i : 63_999]
      end

      def list_line(number, text)
        raise Break if @screen.stop?.call

        @screen.write.call("#{number} #{text}")
        @screen.newline.call
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
    end
  end
end
