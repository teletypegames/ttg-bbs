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

    # +empty+ under the title bar of +heading+, until a key; nil, the
    # nothing a list without items picks.
    def nothing(heading, empty, right: '')
      title(heading, right)
      say(empty, GR)
      pause
      nil
    end

    # Digits up to RETURN: the number, 0 for RETURN alone; nil for q or ←
    # before any digit.
    def number
      digits = +''
      loop do
        k = key
        case k
        when :enter then return entered(digits)
        when :escape, 'q', 'Q' then return quit_number if digits.empty?
        else type_digit(digits, k)
        end
      end
    end

    private

    def entered(digits)
      puts
      digits.to_i
    end

    def quit_number
      puts 'q'
      nil
    end

    # A digit typed (at most four) or the last one rubbed out.
    def type_digit(digits, k)
      if k == :backspace && !digits.empty?
        digits.chop!
        write "\b \b"
      elsif k.is_a?(String) && k.match?(/\A\d\z/) && digits.length < 4
        digits << k
        write k
      end
    end
  end
end
