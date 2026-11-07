# frozen_string_literal: true

module UI
  module Modern
    # The PROFILE tab of the modern face, in the gate's look and among its
    # tabs (TAB goes on to Own Servers): who the caller is, their badges and
    # hunt, and a list of what they can do (UI::Account): log in or make an
    # account, change the password or log out, and the places the boards add
    # to every profile (Feedback, the Wall, The Hunt, Badges, SysOp …). The
    # names and passwords are read on the gate's bottom line, the passwords
    # masked. The arrows choose, RETURN or an item's letter takes it.
    class ProfileTab < Screen
      key(:up) { @index = (@index - 1) % [items.size, 1].max }
      key(:down) { @index = (@index + 1) % [items.size, 1].max }
      key(:enter) { take(items[@index]) }
      key(:tab, :right) { pages.switch }
      key(:left) { pages.switch(-1) }
      key(:escape) { quit }
      key(/\A[[:alpha:]]\z/) { |k| letter(k.downcase) }

      def initialize
        super
        @index  = 0
        @notice = nil
      end

      def lines
        list = items
        @index = @index.clamp(0, [list.size - 1, 0].max)
        body = [*masthead(:profile), who, *facts, '', *list.each_with_index.map { |item, i| row(item, i == @index) }]
        room = rows - 1 - body.size - 5
        body.push('', rule, *about(list[@index], room.clamp(1, 3)), @notice.to_s, hints)
      end

      private

      def account
        @account ||= Account.new(
          session,
          ask: ->(label, mask:, hint:) { ask(label, mask: mask, hint: hint) },
          say: ->(text, good) { @notice = "#{good ? GREEN : RED}#{plain(text)}#{RESET}" }
        )
      end

      def items = account.items

      def who
        name, roles = account.who
        return "#{look.accent}#{BOLD}GUEST#{RESET}  #{TEXT}Not logged in.#{RESET}" unless name

        "#{look.accent}#{BOLD}#{plain(name.upcase)}#{RESET}  #{DIM}#{plain(roles.join(' · '))}#{RESET}"
      end

      def facts
        account.facts.map do |label, words|
          letter = items.find { |i| i.key == (label == 'Badges' ? :badges : :hunt) }&.letter
          "#{DIM}#{label.ljust(10)}#{RESET}#{TEXT}#{plain(words)}#{RESET}#{"  #{DIM}#{letter.upcase} open#{RESET}" if letter}"
        end
      end

      def row(item, lit)
        "#{lit ? "#{SELECTED}#{look.accent}▸" : ' '} #{YELLOW}#{item.letter.upcase}#{RESET}#{SELECTED if lit} " \
          "#{BOLD}#{fit(item.label, 24)}#{RESET}#{SELECTED if lit}#{DIM}#{fit(note(item), width - 29)}#{RESET}"
      end

      def note(item) = item.key == :log_out ? "#{account.who.first} → guest" : ''

      def about(item, room)
        Rubbs::Modern::FrameBuffer.wrap_ansi(item&.about.to_s, width).first(room).map { |l| "#{TEXT}#{l}#{RESET}" }
      end

      def hints = "#{DIM}↑↓ choose  RETURN or letter take  TAB tabs  Q hang up#{RESET}"

      def letter(key)
        item = items.find { |i| i.letter == key }
        return take(item) if item
        return pages.open_tab(:own) if key == 'o'
        return pages.open_tab(:today) if key == 't'

        quit if key == 'q'
      end

      def take(item)
        return unless item

        @index  = items.index(item) || @index
        @notice = nil
        return account.take(item) if account.own?(item)

        place = account.extra(item) or return
        hand_over { place.action.call(session) }
        account.refresh
      end

      def ask(label, mask:, hint:)
        text = read_line("#{label.to_s.capitalize}:", max: 64, mask: mask, hint: hint)
        text.nil? || text.empty? ? nil : text
      end
    end
  end
end
