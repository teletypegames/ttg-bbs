# frozen_string_literal: true

module UI
  module Petscii
    module Views
      # The YOU tab on a C64, in the gate's frame: who the caller is, their
      # badges and hunt, and a numbered list of what they can do
      # (UI::Account): log in or make an account, change the password or
      # log out, and the places the boards add to every profile (Feedback,
      # the Wall, The Hunt, Badges, SysOp …). CRSR moves, RETURN or the
      # number takes it; names and passwords are read on the hint row, the
      # passwords as stars. The gate's hotkeys (O, D, T, Q …) stay.
      class ProfileView < Rubbs::Petscii::Kit::Picker
        # Items a page.
        PER_PAGE = 9
        # The keys on the hint bar.
        HINT = [['CRSR', true], [' Move  ', false], ['RETURN', true], [' Take  ', false], ['O', true], [' Own', false]].freeze
        # The columns a name or a password may take on the hint row.
        INPUT_MAX = 20

        # The account's view of the caller on +session+.
        def initialize(session)
          super([], per_page: PER_PAGE)
          @session = session
          @notice  = nil
        end

        def section = :account

        def hint = HINT

        def draw(canvas)
          reload_items(account.items)
          name, roles = account.who
          Layout.band(canvas, 'YOU', name ? 'LOGGED IN' : 'GUEST', Canvas::LIGHT_BLUE)
          top = head(canvas, name, roles)
          on_page.each_with_index { |item, slot| row(canvas, Layout.row(top + slot), item, slot) }
          below(canvas, top + PER_PAGE + 1)
        end

        # Does the account's own +item+, or runs the place it is.
        def take(item)
          @notice = nil
          return account.take(item) if account.own?(item)

          place = account.extra(item) or return
          hand_over { place.action.call(@session) }
          account.refresh
        end

        private

        def account
          @account ||= Account.new(
            @session,
            ask: ->(label, mask:, hint:) { ask(label, mask: mask, hint: hint) },
            say: ->(text, good) { @notice = [text, good ? Canvas::LIGHT_GREEN : Canvas::LIGHT_RED] }
          )
        end

        # The name, the roles and the facts from content row 2; the row the
        # list starts on.
        def head(canvas, name, roles)
          if name
            Layout.runs(canvas, Layout.row(2), 1, [[Layout.plain(name), Canvas::WHITE], ["  #{roles.join(' ')}", Canvas::GREY]])
          else
            canvas.text(Layout.row(2), 1, 'Not logged in.', Canvas::LIGHT_GREY)
          end
          facts = account.facts.first(2)
          facts.each_with_index do |(label, words), i|
            Layout.runs(canvas, Layout.row(3 + i), 1, [[label.ljust(9), Canvas::GREY], [Layout.plain(words), Canvas::CYAN]])
          end
          4 + facts.size
        end

        def row(canvas, row, item, slot)
          number = ((@page * @per_page) + slot + 1).to_s
          label  = Layout.plain(item.label)
          if slot == @index
            canvas.text(row, 0, " #{number} #{label}".ljust(Layout::WIDTH), Canvas::CYAN, rvs: true)
          else
            Layout.runs(canvas, row, 0, [[" #{number} ", Canvas::YELLOW], [label, Canvas::WHITE]])
          end
        end

        # Under a rule: what the lit item does, and the notice of the last
        # one taken.
        def below(canvas, line)
          return if line > Layout::ROWS - 3

          Layout.rule(canvas, Layout.row(line))
          room = Layout::ROWS - line - 3
          Layout.wrap(selected&.about.to_s, Layout::EDGE - 1, room.clamp(1, 3)).each_with_index do |text, i|
            canvas.text(Layout.row(line + 1 + i), 1, text, Canvas::LIGHT_GREY)
          end
          text, color = @notice
          canvas.text(Layout.row(Layout::ROWS - 1), 1, Layout.plain(text.to_s)[0, Layout::EDGE - 1], color) if text
        end

        def ask(label, mask:, hint:)
          text = read_line("#{label.to_s.capitalize}:", max: INPUT_MAX, mask: mask, hint: hint)&.strip
          text.nil? || text.empty? ? nil : text
        end
      end
    end
  end
end
