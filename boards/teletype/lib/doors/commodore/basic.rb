# frozen_string_literal: true

require_relative 'basic/statements'
require_relative 'basic/expressions'
require_relative 'basic/tokenizer'

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
  #
  # The statements, the expressions and the tokenizer are modules of their
  # own (basic/*.rb); this class keeps the program and runs it.
  class Basic
    include Statements
    include Expressions
    include Tokenizer

    Screen = Struct.new(:write, :newline, :column, :cls, :readline, :stop?, keyword_init: true)

    class Error < StandardError; end
    class Break < StandardError; end
    class Reset < StandardError; end

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
    rescue ZeroDivisionError, RangeError
      report('OVERFLOW')
    rescue SystemStackError
      report('OUT OF MEMORY')
    rescue Break
      report_break
    end

    def report(message)
      @screen.newline.call unless @screen.column.call.zero?
      @screen.write.call("?#{message}  ERROR#{where}")
      @screen.newline.call
    end

    def report_break
      @screen.newline.call unless @screen.column.call.zero?
      @screen.write.call("BREAK#{where}")
      @screen.newline.call
    end

    def where = @line_index ? " IN #{@lines[@line_index][0]}" : ''

    # Runs statements from @toks/@pos; in program mode it moves on to the
    # next line at the end of each one.
    def execute
      @steps = 0
      loop do
        statement_loop
        return if @halted || @line_index.nil?

        @line_index += 1
        return if @line_index >= @lines.size

        enter_line(@line_index, 0)
      end
    ensure
      @halted = false
    end

    def statement_loop
      while @pos < @toks.size
        count_step
        if op?(@toks[@pos], ':')
          @pos += 1
          next
        end
        statement
        return if @halted
      end
    end

    # RUN/STOP is looked at every 500 steps, and a runaway program stops.
    def count_step
      @steps += 1
      raise Break if @steps > MAX_STEPS
      raise Break if (@steps % 500).zero? && @screen.stop?.call
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

    # ── reading the tokens ─────────────────────────────────────────────────

    def line_number
      tok = advance
      raise Error, 'SYNTAX' unless tok&.type == :num

      tok.value.to_i
    end

    def statement_end? = @pos >= @toks.size || op?(@toks[@pos], ':')

    def kw?(word) = @toks[@pos]&.type == :kw && @toks[@pos].value == word

    def op?(tok, value) = tok&.type == :op && tok.value == value

    def advance
      tok = @toks[@pos]
      @pos += 1 if tok
      tok
    end

    # The items of a comma-separated list, each read by the block.
    def comma_list
      items = [yield]
      while op?(@toks[@pos], ',')
        @pos += 1
        items << yield
      end
      items
    end

    def expect_op(op)
      raise Error, 'SYNTAX' unless op?(advance, op)
    end

    def expect_kw(word)
      tok = advance
      raise Error, 'SYNTAX' unless tok&.type == :kw && tok.value == word
    end
  end
end
