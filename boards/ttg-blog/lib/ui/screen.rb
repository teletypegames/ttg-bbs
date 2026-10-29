# frozen_string_literal: true

module UI
  # Colours as ANSI: a modern terminal shows them as they are, and a PETSCII
  # line turns them into the C64's own. The width helpers of rubbs know ANSI
  # and would count PETSCII codes as text.
  WH = "\e[1;37m"
  YE = "\e[1;33m"
  CY = "\e[0;36m"
  LG = "\e[0;37m"
  GR = "\e[2;37m"
  DG = "\e[1;30m"
  GN = "\e[1;32m"
  RD = "\e[1;31m"
  RV = "\e[7m"
  RO = "\e[27m"

  # The colours of a post, in the keys of a BBS::Theme.
  MARKDOWN = { text: LG, text_bright: WH, accent: YE, label: CY, text_dim: GR }.freeze

  # The screen of one call and the ways a line-by-line board talks: a title
  # bar, pages of text that wait for RETURN, numbered lists and single-key
  # menus. The same on both faces, only its size differs: 40×25 on a C64,
  # the caller's window up to 80 columns on a modern terminal.
  class Screen
    attr_reader :session, :cols, :width

    def initialize(session, cols:, rows:)
      @session = session
      @cols    = cols
      @rows    = rows
      @width   = cols - 2
    end

    def page_size = @rows - 5

    def write(text) = @session.write(text)

    def puts(text = '')
      write("#{text}\r\n")
    end

    # PETSCII CLR homes the cursor itself; the HOME after it, 0x13, is XOFF
    # to a modem or terminal on software flow control.
    def cls = write(@session.petscii? ? "\e[0m\e[2J" : "\e[0m\e[2J\e[H")

    # A clear screen under a reversed title bar.
    def title(text, right = '')
      cls
      bar = " #{text}".ljust(@cols - right.length - 1)[0, @cols - right.length - 1] + "#{right} "
      puts "#{CY}#{RV}#{bar}#{RO}#{LG}"
    end

    def rule(color = DG) = puts("#{color}#{'─' * (@cols - 1)}#{LG}")

    def wrap(text, width = @width) = BBS::FrameBuffer.wrap_ansi(text.to_s, width)

    # Every line of +lines+ cut to the screen, the long ones wrapped under
    # their own indent.
    def fit(lines, width = @cols - 1)
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

    # A key; a hang-up ends the call.
    def key
      k = @session.readkey
      raise IOError, 'the caller hung up' if k.nil?

      k
    end

    # One of +keys+ (lowercase letters); ← and RUN/STOP or Esc give +back+.
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

    # A line typed by the caller, trimmed and cut to +max+.
    def ask(prompt, mask: nil, max: nil)
      write prompt
      line = @session.readline(mask: mask)
      raise IOError, 'the caller hung up' if line.nil?

      line = line.strip
      max ? line[0, max] : line
    end

    # A line as typed: the line editor keeps the spaces a line starts with.
    def line(prompt)
      write prompt
      line = @session.readline
      raise IOError, 'the caller hung up' if line.nil?

      line.rstrip
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
      per   = wait ? page_size : page_size - 2
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

    # A numbered list of +items+ by +label+; the item picked, or nil.
    def pick(heading, items, empty: '(nothing here)', right: '', &label)
      if items.empty?
        title(heading, right)
        say(empty, GR)
        pause
        return nil
      end
      per   = page_size - 1
      pages = items.each_slice(per).to_a
      index = 0
      loop do
        title(heading, right)
        pages[index].each_with_index do |item, i|
          n = (index * per) + i + 1
          puts "#{YE}#{n.to_s.rjust(3)}#{LG} #{BBS::FrameBuffer.clip_ansi(label.call(item).to_s, @cols - 6)}"
        end
        more = if pages.size > 1
                 " return: #{index + 1 < pages.size ? 'more' : 'top'}"
               else
                 ''
               end
        write "\r\n#{DG}number#{more}  q: back#{LG}\r\n> "
        answer = number
        if answer.nil?
          return nil
        elsif answer.zero?
          index = (index + 1) % pages.size
        elsif answer <= items.size
          return items[answer - 1]
        end
      end
    end

    # Digits up to RETURN: the number, 0 for RETURN alone; nil for q or ←
    # before any digit.
    def number
      digits = +''
      loop do
        k = key
        case k
        when :enter
          puts
          return digits.to_i
        when :escape, 'q', 'Q'
          next unless digits.empty?

          puts 'q'
          return nil
        when :backspace
          next if digits.empty?

          digits.chop!
          write "\b \b"
        when /\A\d\z/
          next if digits.length >= 4

          digits << k
          write k
        end
      end
    end
  end
end
