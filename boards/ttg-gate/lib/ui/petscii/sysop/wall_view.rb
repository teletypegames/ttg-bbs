# frozen_string_literal: true

module UI
  module Petscii
    module Sysop
      # The walls of every board (TTG::Wall) on a C64, hidden notes too,
      # newest first: a row each (an x for a hidden one, who, the board),
      # under a rule the lit note. H hides it or shows it again, B bars the
      # line of a guest's note from the walls for a day.
      class WallView < Views::Picker
        include Shared

        PER_PAGE = 8
        HINT = [['H', true], ['ide/show  ', false], ['B', true], ['ar guest  ', false], ['←', true], [' Back', false]].freeze

        every(10) { redraw }

        key('h', 'H') { guarded { hide(selected) } }
        key('b', 'B') { guarded { bar(selected) } }

        def initialize(_accounts)
          super([], per_page: PER_PAGE)
        end

        def section = :wall

        def hint = HINT

        def take(note) = guarded { hide(note) }

        def draw(canvas)
          reload_items(UI::Sysop.walls(session, :moderation, limit: 100)['notes'] || [])
          Layout.band(canvas, 'WALL', page_mark.to_s, Canvas::YELLOW)
          on_page.each_with_index do |note, slot|
            list_row(
              canvas,
              Layout.row(1 + slot),
              slot,
              UI::Sysop.writer(note),
              note['board'].to_s.delete_suffix('-bbs')[0, 9],
              mark: note['hidden_at'] ? 'x' : nil
            )
          end
          detail(canvas, selected)
        end

        private

        def detail(canvas, note)
          top = Layout.row(1 + PER_PAGE)
          return facts(canvas, top, [['', 'Nothing on the walls.', Canvas::GREY]]) unless note

          text = Rubbs::Modern::FrameBuffer.wrap_ansi(Layout.plain(note['text'].to_s), 30)
          facts(canvas, top, [['When', when_text(note['created_at'])], *text.first(3).map { |line| ['', line, Canvas::WHITE] }])
        end

        def hide(note)
          return unless note

          UI::Sysop.walls(session, note['hidden_at'] ? :unhide : :hide, id: note['id'], reason: 'sysop')
        end

        def bar(note)
          return tell('Only a guest can be barred.', 'Ban an account on ACCOUNTS.') unless note&.fetch('guest', false)
          return unless yes?("Bar #{note['name']} from the walls", 'for a day?')

          UI::Sysop.walls(session, :bar, id: note['id'], hours: 24)
        end
      end
    end
  end
end
