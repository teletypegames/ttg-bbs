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

    # Letters the C64 has no glyph for and the rubbs encoder would show as
    # a question mark.
    SPELLED = { 'æ' => 'ae', 'Æ' => 'Ae', 'œ' => 'oe', 'Œ' => 'Oe', 'ø' => 'o', 'Ø' => 'O', 'ł' => 'l', 'Ł' => 'L',
                'đ' => 'd', 'Đ' => 'D', 'þ' => 'th', 'Þ' => 'Th', 'ð' => 'd', 'Ð' => 'D', 'ı' => 'i',
                '″' => '"', '′' => "'", '¡' => '!', '¿' => '?', '§' => 'S.', '¶' => '' }.freeze

    # The 40×25 screen of one call and the ways a C64 board talks: a title
    # bar, pages of text that wait for RETURN, numbered lists and single-key
    # menus. The session, switched with petscii!, makes PETSCII of what it
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
        text = plain(text)
        bar = " #{text}".ljust(COLS - right.length - 1)[0, COLS - right.length - 1] + "#{right} "
        puts "#{CY}#{RV}#{bar}#{RO}#{LG}"
      end

      def rule(color = DG) = puts("#{color}#{'─' * (COLS - 1)}#{LG}")

      def wrap(text, width = WIDTH) = BBS::FrameBuffer.wrap_ansi(text.to_s, width)

      # +text+ in characters the C64 shows one to a cell, so it wraps where
      # it is counted: typography and accented letters become ASCII (an
      # ellipsis three dots, a dash a hyphen), the box drawing and block
      # glyphs of the encoder stay, anything else is a question mark.
      def self.plain(text)
        text.to_s.gsub(/[^ -~\e]/) do |c|
          glyph = BBS::Petscii::GLYPHS[c]
          next glyph if glyph&.ascii_only?
          next c if glyph
          next SPELLED[c] if SPELLED.key?(c)

          base = c.unicode_normalize(:nfkd).gsub(BBS::Petscii::COMBINING_MARK, '')
          base.length == 1 && base.ascii_only? ? base : '?'
        end
      end

      def plain(text) = self.class.plain(text)

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
        wrap(plain(text)).each { |l| puts " #{color}#{l}#{LG}" }
      end

      # A key, :idle after +timeout+ seconds; a hang-up ends the call.
      def key(timeout: nil)
        k = @session.readkey(timeout: timeout)
        raise IOError, 'the caller hung up' if k.nil?

        k
      end

      # One of +keys+ (lowercase letters); ← and RUN/STOP give +back+.
      def choose(prompt, keys, back: 'q')
        write "\r\n#{prompt}"
        loop do
          k = key
          k = back if k == :escape
          k = k.downcase if k.is_a?(String)
          next unless keys.include?(k)

          puts(k.is_a?(String) ? k.upcase : '')
          return k
        end
      end

      def pause(text = 'return: back')
        write "\r\n #{DG}#{text}#{LG} "
        k = key
        puts
        k
      end

      # Lines one screenful at a time under +heading+; q leaves early. With
      # +wait+ false the last screenful does not wait: a command line follows.
      def page(heading, lines, right: '', wait: true)
        lines = fit(lines)
        lines = [" #{GR}(nothing here)#{LG}"] if lines.empty?
        per   = wait ? PAGE : PAGE - 1
        chunks = lines.each_slice(per).to_a
        chunks.each_with_index do |chunk, i|
          title(heading, right)
          chunk.each { |l| puts l }
          last = i == chunks.size - 1
          next if last && !wait

          k = pause(last ? 'return: back' : 'return: more  q: back')
          break if !last && (k == :escape || k.to_s.downcase == 'q')
        end
        nil
      end

      # The colours of a menu: the bar in the title bar's cyan.
      MENU = { text: LG, key: YE, bar: CY, heading: DG, about: GR, hint: DG }.freeze

      # A numbered list of +items+ by +label+ under a title bar, a menu of
      # rubbs (BBS::Selector); the item picked, or nil. CRSR and RETURN or
      # the number pick; q, ← or RUN/STOP go back.
      def pick(heading, items, empty: '(nothing here)', right: '', &label)
        title(heading, right)
        if items.empty?
          say(empty, GR)
          pause
          return nil
        end
        BBS::Selector.list(@session, items, width: COLS - 1, height: PAGE, hint: 'crsr or number, return  q: back',
                                            exits: { 'q' => nil }, colors: MENU) { |item| plain(label.call(item)) }
      end

      # A menu of +items+ (BBS::Selector::Item) at the cursor: the value of
      # the one taken, +back+ for ← or RUN/STOP. The other options are those
      # of BBS::Selector.new.
      def menu(items, back: nil, **)
        BBS::Selector.new(@session, items, width: COLS - 1, back: back, colors: MENU, **).run
      end

      # The keys of +actions+ ([key, label] pairs) on one row under what is
      # on the screen, the cursor moving along it: the key taken; q for ←
      # or RUN/STOP.
      def actions(*actions)
        puts
        menu(actions.map { |k, label| BBS::Selector.item(label, key: k, value: k) }, across: true, back: 'q')
      end
    end
  end
end
