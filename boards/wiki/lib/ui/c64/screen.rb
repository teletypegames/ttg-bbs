# frozen_string_literal: true

module UI
  module C64
    # Colours as ANSI, which the PETSCII line turns into the C64's own; the
    # width helpers of rubbs know ANSI and would count PETSCII codes as text.
    WH = "\e[1;37m"
    YE = "\e[1;33m"
    CY = "\e[0;36m"
    LG = "\e[0;37m"
    GR = "\e[2;37m"
    DG = "\e[1;30m"
    LB = "\e[1;34m"
    GN = "\e[1;32m"
    RD = "\e[1;31m"
    RV = "\e[7m"
    RO = "\e[27m"

    COLS  = 40
    WIDTH = 38

    # The 40×25 screen of one call and the ways a C64 board talks: a title
    # bar, pages of text that wait for RETURN, numbered lists and single-key
    # commands. The session, switched with petscii!, makes PETSCII of what it
    # writes.
    class Screen
      PAGE = 20

      attr_reader :session

      def initialize(session)
        @session = session
      end

      def write(text) = @session.write(text)

      def puts(text = '')
        write("#{text}\r\n")
      end

      def cls = write(BBS::Petscii::CLEAR)

      # A clear screen under a reversed title bar.
      def title(text, right = '')
        cls
        bar = " #{text}".ljust(COLS - right.length - 1)[0, COLS - right.length - 1] + "#{right} "
        puts "#{CY}#{RV}#{bar}#{RO}#{LG}"
      end

      def wrap(text, width = WIDTH) = BBS::FrameBuffer.wrap_ansi(text.to_s, width)

      # Every line of +lines+ cut to the screen, the long ones wrapped under
      # their own indent.
      def fit(lines, width = COLS - 1)
        lines.flat_map do |l|
          next [''] if l.to_s.empty?

          indent = BBS::FrameBuffer.text(l.to_s).gsub(BBS::FrameBuffer::ANSI_ESC_RE, '')[/\A */]
          first, *rest = wrap(l, width)
          next [first] if rest.empty?

          [first, *wrap(rest.join(' '), width - indent.size).map { |r| "#{indent}#{r}" }]
        end
      end

      def say(text, color = LG)
        wrap(text).each { |l| puts " #{color}#{l}#{LG}" }
      end

      # A key, :idle after +timeout+ seconds; a hang-up ends the call.
      def key(timeout: nil)
        k = @session.readkey(timeout: timeout)
        raise IOError, 'the caller hung up' if k.nil?

        k
      end

      # One of +keys+ (lowercase letters); ← and RUN/STOP give +back+.
      def choose(prompt, keys, back: 'n')
        write "\r\n#{prompt}"
        loop do
          k = key
          k = back if k == :escape
          k = k.downcase if k.is_a?(String)
          next unless keys.include?(k)

          puts(k.upcase)
          return k
        end
      end

      # A line typed by the caller.
      def ask(prompt, mask: nil, max: nil)
        write prompt
        line = @session.readline(mask: mask)
        raise IOError, 'the caller hung up' if line.nil?

        line = line.strip
        max ? line[0, max] : line
      end

      def pause(text = 'return: back')
        write "\r\n #{DG}#{text}#{LG} "
        k = key
        puts
        k
      end

      # Lines one screenful at a time under +heading+; q leaves early.
      def page(heading, lines, right: '')
        lines  = fit(lines)
        lines  = [" #{GR}(nothing here)#{LG}"] if lines.empty?
        chunks = lines.each_slice(PAGE).to_a
        chunks.each_with_index do |chunk, i|
          title(heading, "#{right}#{i + 1}/#{chunks.size}")
          chunk.each { |l| puts l }
          last = i == chunks.size - 1
          k = pause(last ? 'return: back' : 'return: more  q: back')
          break if !last && (k == :escape || k.to_s.downcase == 'q')
        end
        nil
      end

      # A numbered list of +items+ by +label+ under +heading+, with single-key
      # +commands+ ({ 's' => 'login' }) on the help line. The item picked, the
      # command letter pressed, or nil for q / ←.
      def pick(heading, items, commands: {}, right: '', &label)
        per   = PAGE - 3
        pages = items.each_slice(per).to_a
        pages = [[]] if pages.empty?
        index = 0
        loop do
          title(heading, right)
          pages[index].each_with_index do |item, i|
            n = (index * per) + i + 1
            puts "#{YE}#{n.to_s.rjust(3)}#{LG} #{BBS::FrameBuffer.clip_ansi(label.call(item).to_s, COLS - 6)}"
          end
          say('(nothing here)', GR) if items.empty?
          more = pages.size > 1 ? "  return: #{index + 1 < pages.size ? 'more' : 'top'}" : ''
          help = commands.map { |k, v| "#{k}: #{v}" }.join('  ')
          write "\r\n#{DG}number#{more}  q: back#{LG}\r\n"
          write "#{DG}#{help}#{LG}\r\n" unless help.empty?
          write '> '
          answer = number(commands.keys)
          case answer
          when nil, String then return answer
          when 0 then index = (index + 1) % pages.size
          else return items[answer - 1] if answer <= items.size
          end
        end
      end

      # Digits up to RETURN: the number, 0 for RETURN alone; nil for q or ←,
      # or one of +letters+, before any digit.
      def number(letters = [])
        digits = +''
        loop do
          k = key
          case k
          when :enter
            puts
            return digits.to_i
          when :escape, 'q', 'Q'
            next unless digits.empty?

            puts 'Q'
            return nil
          when :backspace
            next if digits.empty?

            digits.chop!
            write "\b \b"
          when /\A\d\z/
            next if digits.length >= 4

            digits << k
            write k
          when String
            letter = k.downcase
            next unless digits.empty? && letters.include?(letter)

            puts letter.upcase
            return letter
          end
        end
      end
    end
  end
end
