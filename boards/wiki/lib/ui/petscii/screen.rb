# frozen_string_literal: true

module UI
  module Petscii
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
    # bar, pages of text that wait for RETURN, numbered cursor menus and
    # single-key commands. The session, switched with petscii!, makes PETSCII of what it
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

      # A line typed by the caller in a field of rubbs after +prompt+,
      # starting from +text+; trimmed, and empty when the caller cancelled
      # with RUN/STOP or ←.
      def ask(prompt, text: '', mask: nil, max: nil)
        BBS::Field.ask(@session, prompt, text: text, max: max, mask: mask, cols: BBS::Petscii::COLS).to_s.strip
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

      # The colours of a menu: the bar in the title bar's cyan.
      MENU = { text: LG, key: YE, bar: CY, heading: DG, about: GR, hint: DG }.freeze

      # A numbered list of +items+ by +label+ under +heading+, a cursor menu
      # of rubbs (BBS::Selector): CRSR and RETURN or the number pick, CRSR
      # left and right turn the pages. Single-key +commands+
      # ({ 's' => 'login' }) are on the hint line. The item picked, the
      # command letter pressed, or nil for q / ←.
      def pick(heading, items, commands: {}, right: '', &label)
        title(heading, right)
        if items.empty?
          say('(nothing here)', GR)
          pause
          return nil
        end
        hint = if commands.empty? then 'crsr or number, return  q: back'
               else "#{commands.map { |k, v| "#{k}: #{v}" }.join('  ')}  q: back"
               end
        BBS::Selector.list(@session, items, width: COLS - 1, height: PAGE, hint: hint, colors: MENU,
                                            exits: commands.keys.to_h { |k| [k, k] }.merge('q' => nil), &label)
      end

    end
  end
end
