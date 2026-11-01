# frozen_string_literal: true

module UI
  # The colours of rubbs (BBS::Petscii::Colors) as ANSI: a modern terminal
  # shows them as they are, and a PETSCII line turns them into the C64's own.
  BBS::Petscii::Colors.install(self)

  # The colours of a post, in the keys of a BBS::Theme.
  MARKDOWN = { text: LG, text_bright: WH, accent: YE, label: CY, text_dim: GR }.freeze

  # The screen of one call (BBS::Petscii::Screen): a title bar, pages of
  # text that wait for RETURN, lists and single-key menus. The same on both
  # faces, only its size differs: 40×25 on a C64, the caller's window up to
  # 80 columns on a modern terminal.
  class Screen < BBS::Petscii::Screen
    # +question+ under the text, answered with y or n; true for y.
    def confirm?(question, color)
      puts
      say(question, color)
      choose(" #{WH}y/n#{LG}> ", %w[y n], back: 'n') == 'y'
    end

    # +text+ under the text, after a blank line with +gap+, until a key.
    def notice(text, color, gap: true)
      puts if gap
      say(text, color)
      pause
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
