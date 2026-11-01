# frozen_string_literal: true

module Commodore
  class Basic
    # A line of text into Tokens: keywords, numbers, strings, names and
    # operators. Keywords are found anywhere outside strings, even inside a
    # name: TOTAL reads as TO TAL, the way the machine's own cruncher read it.
    module Tokenizer
      KEYWORDS = %w[
        PRINT GOTO GOSUB RETURN IF THEN FOR TO STEP NEXT END STOP REM LET INPUT
        POKE PEEK CLR LIST RUN NEW SYS AND OR NOT RND INT ABS SGN SQR SIN COS TAN
        LEN STR$ VAL CHR$ ASC LEFT$ RIGHT$ MID$
      ].sort_by { |k| -k.length }.freeze
      OPERATORS = '+-*/^()=<>,;:'
      PAIRS     = %w[<> <= >=].freeze

      private

      def tokenize(text)
        tokens = []
        i = 0
        i = scan(text, i, tokens) while i && i < text.length
        tokens
      end

      # Reads the token at +i+ into +tokens+; returns where the next one
      # starts, or nil after a REM, whose remark is the rest of the line.
      def scan(text, i, tokens)
        ch = text[i]
        return i + 1 if ch == ' '
        return scan_string(text, i, tokens) if ch == '"'
        return push(tokens, :kw, 'PRINT', i + 1) if ch == '?'
        return scan_number(text, i, tokens) if ch.match?(/[0-9.]/)

        keyword = keyword_at(text, i)
        return scan_keyword(text, i, keyword, tokens) if keyword
        return scan_name(text, i, tokens) if ch.match?(/[A-Z]/)

        scan_operator(text, i, tokens)
      end

      def push(tokens, type, value, next_index)
        tokens << Token.new(type, value)
        next_index
      end

      def scan_string(text, i, tokens)
        close = text.index('"', i + 1) || text.length
        push(tokens, :str, text[(i + 1)...close], close + 1)
      end

      def scan_number(text, i, tokens)
        literal = text[i..][/\A(\d*\.?\d*)(E[-+]?\d+)?/]
        raise Error, 'SYNTAX' if literal == '.'

        push(tokens, :num, literal.to_f, i + literal.length)
      end

      def scan_keyword(text, i, keyword, tokens)
        i = push(tokens, :kw, keyword, i + keyword.length)
        return i unless keyword == 'REM'

        push(tokens, :rem, text[i..], nil)
      end

      # Only the first two letters of a name count; a $ makes it a string.
      def scan_name(text, i, tokens)
        start = i
        i += 1
        i += 1 while i < text.length && text[i].match?(/[A-Z0-9]/) && !keyword_at(text, i)
        name = text[start...i][0, 2]
        return push(tokens, :var, name, i) unless text[i] == '$'

        push(tokens, :var, "#{name}$", i + 1)
      end

      def scan_operator(text, i, tokens)
        pair = text[i, 2]
        return push(tokens, :op, pair, i + 2) if PAIRS.include?(pair)
        raise Error, 'SYNTAX' unless OPERATORS.include?(text[i])

        push(tokens, :op, text[i], i + 1)
      end

      def keyword_at(text, i)
        KEYWORDS.find { |kw| text[i, kw.length] == kw }
      end
    end
  end
end
