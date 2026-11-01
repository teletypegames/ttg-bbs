# frozen_string_literal: true

module Commodore
  class Basic
    # Expressions by precedence (OR, AND, NOT, relations, + -, * /, unary,
    # ^), the functions, and the values they work on: floats and strings.
    module Expressions
      # Each function's method; it gets the arguments as an Array.
      FUNCTIONS = {
        'RND' => :fn_rnd, 'INT' => :fn_int, 'ABS' => :fn_abs, 'SGN' => :fn_sgn, 'SQR' => :fn_sqr,
        'SIN' => :fn_sin, 'COS' => :fn_cos, 'TAN' => :fn_tan, 'LEN' => :fn_len, 'STR$' => :fn_str,
        'VAL' => :fn_val, 'CHR$' => :fn_chr, 'ASC' => :fn_asc, 'LEFT$' => :fn_left, 'RIGHT$' => :fn_right,
        'MID$' => :fn_mid, 'PEEK' => :fn_peek
      }.freeze
      RELATIONS = {
        '=' => :==, '<>' => :!=, '<' => :<, '>' => :>, '<=' => :<=, '>=' => :>=
      }.freeze
      WORD = -32_768..32_767

      private

      def expression = expr_or

      def expr_or
        left = expr_and
        while kw?('OR')
          @pos += 1
          left = (integer(left, WORD) | integer(expr_and, WORD)).to_f
        end
        left
      end

      def expr_and
        left = expr_not
        while kw?('AND')
          @pos += 1
          left = (integer(left, WORD) & integer(expr_not, WORD)).to_f
        end
        left
      end

      def expr_not
        return expr_relation unless kw?('NOT')

        @pos += 1
        (~integer(expr_not, WORD)).to_f
      end

      def expr_relation
        left = expr_add
        while (op = relation_op)
          right = expr_add
          raise Error, 'TYPE MISMATCH' unless left.instance_of?(right.class)

          left = left.public_send(RELATIONS[op], right) ? -1.0 : 0.0
        end
        left
      end

      def relation_op
        tok = @toks[@pos]
        return nil unless tok&.type == :op && RELATIONS.key?(tok.value)

        @pos += 1
        tok.value
      end

      def expr_add
        left = expr_mul
        while (op = op_of(%w[+ -]))
          right = expr_mul
          left = add(op, left, right)
        end
        left
      end

      def add(op, left, right)
        return number(left) - number(right) if op == '-'
        return number(left) + number(right) unless left.is_a?(String) && right.is_a?(String)

        raise Error, 'STRING TOO LONG' if left.length + right.length > 255

        left + right
      end

      def expr_mul
        left = expr_unary
        while (op = op_of(%w[* /]))
          right = number(expr_unary)
          raise Error, 'DIVISION BY ZERO' if op == '/' && right.zero?

          left = op == '*' ? number(left) * right : number(left) / right
        end
        left
      end

      def expr_unary
        op = op_of(%w[- +])
        return expr_power unless op

        value = number(expr_unary)
        op == '-' ? -value : value
      end

      def expr_power
        left = primary
        while op_of(%w[^])
          left = number(left)**number(primary)
          raise Error, 'ILLEGAL QUANTITY' if left.is_a?(Complex)
        end
        left
      end

      # The operator at the cursor when it is one of +ops+ (and steps over
      # it), else nil.
      def op_of(ops)
        tok = @toks[@pos]
        return unless tok&.type == :op && ops.include?(tok.value)

        @pos += 1
        tok.value
      end

      def primary
        tok = advance
        raise Error, 'SYNTAX' unless tok

        case tok.type
        when :num, :str then tok.value
        when :var then @vars.fetch(tok.value) { tok.value.end_with?('$') ? '' : 0.0 }
        when :op  then parenthesis(tok)
        when :kw  then function(tok)
        end
      end

      def parenthesis(tok)
        raise Error, 'SYNTAX' unless tok.value == '('

        value = expression
        expect_op(')')
        value
      end

      def function(tok)
        raise Error, 'SYNTAX' unless FUNCTIONS.key?(tok.value)

        expect_op('(')
        args = comma_list { expression }
        expect_op(')')
        send(FUNCTIONS[tok.value], args)
      end

      # ── the functions ─────────────────────────────────────────────────────

      def fn_rnd(_args) = rand
      def fn_int(args)  = number(args[0]).floor.to_f
      def fn_abs(args)  = number(args[0]).abs
      def fn_sgn(args)  = (number(args[0]) <=> 0).to_f
      def fn_sin(args)  = Math.sin(number(args[0]))
      def fn_cos(args)  = Math.cos(number(args[0]))
      def fn_tan(args)  = Math.tan(number(args[0]))
      def fn_len(args)  = string(args[0]).length.to_f
      def fn_str(args)  = format_number(number(args[0])).rstrip
      def fn_val(args)  = string(args[0]).strip[/\A[-+]?(\d+\.?\d*|\.\d+)(E[-+]?\d+)?/i].to_f
      def fn_chr(args)  = petscii(integer(args[0], 0..255))
      def fn_left(args) = string(args[0])[0, integer(args[1], 0..255)]
      def fn_peek(args) = @memory.fetch(integer(args[0], 0..65_535), 0).to_f

      def fn_sqr(args)
        raise Error, 'ILLEGAL QUANTITY' if number(args[0]).negative?

        Math.sqrt(args[0])
      end

      def fn_asc(args)
        raise Error, 'ILLEGAL QUANTITY' if string(args[0]).empty?

        string(args[0]).ord.to_f
      end

      def fn_right(args)
        n = integer(args[1], 0..255)
        n.zero? ? '' : string(args[0])[-n..] || string(args[0])
      end

      def fn_mid(args)
        start = integer(args[1], 1..255) - 1
        string(args[0])[start, args[2] ? integer(args[2], 0..255) : 255] || ''
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

      # ── values ────────────────────────────────────────────────────────────

      def assign(name, value)
        raise Error, 'TYPE MISMATCH' unless name.end_with?('$') == value.is_a?(String)

        @vars[name] = value
      end

      def numeric?(text) = text.to_s.match?(/\A[-+]?(\d+\.?\d*|\.\d+)(E[-+]?\d+)?\z/i)

      def truthy?(value) = value.is_a?(String) ? !value.empty? : !value.zero?

      def number(value)
        raise Error, 'TYPE MISMATCH' if value.is_a?(String)

        value = value.to_f
        raise Error, 'OVERFLOW' unless value.finite?

        value
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
    end
  end
end
