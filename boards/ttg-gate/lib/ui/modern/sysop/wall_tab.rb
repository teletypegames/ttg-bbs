# frozen_string_literal: true

module UI
  module Modern
    module Sysop
      # The walls of every board (TTG::Wall), hidden notes too, newest first:
      # a row each (a ✖ for a hidden one, the board, who, the note), under
      # the list the chosen note whole. H hides it or shows it again, B bars
      # the line of a guest's note from the walls for a day.
      class WallTab < View
        every(10) { redraw }

        key(:up) { @index = [@index - 1, 0].max }
        key(:down) { @index = (@index + 1).clamp(0, [notes.size - 1, 0].max) }
        key('h', 'H') { guarded { hide(notes[@index]) } }
        key('b', 'B') { guarded { bar(notes[@index]) } }

        def initialize(accounts)
          super
          @index = 0
        end

        private

        def tab = :wall

        def notes = UI::Sysop.walls(session, :moderation, limit: 100)['notes'] || []

        def body
          list = notes
          @index = @index.clamp(0, [list.size - 1, 0].max)
          rows = if list.empty?
                   ["#{DIM}Nothing on the walls.#{RESET}"]
                 else
                   window(list, @index, per_page) { |note, lit|
                     row(note, lit)
                   }
                 end
          [crumbs('WALL', "#{list.size} newest"), *rows, '', rule, *detail(list[@index]), *(@notice ? ['', @notice] : [])]
        end

        def row(note, lit)
          bg   = lit ? SELECTED : ''
          mark = note['hidden_at'] ? "#{RED}✖#{RESET}" : ' '
          "#{lit ? "#{bg}#{look.accent}▸" : ' '}#{mark}#{bg} #{TEXT}#{fit(note['board'].to_s.delete_suffix('-bbs'), 12)} " \
            "#{BOLD}#{fit(UI::Sysop.writer(note), 18)}#{RESET}#{bg} #{TEXT}#{fit(note['text'], [width - 36, 8].max)}#{RESET}"
        end

        def detail(note)
          return [] unless note

          [fact('When', when_text(note['created_at'])), *(note['reply_name'] ? [fact('Answers', note['reply_name'])] : []),
           *(note['hidden_at'] ? [fact('Hidden', "#{note['hidden_by']}: #{note['reason']}")] : []),
           "#{TEXT}#{fit(note['text'], width)}#{RESET}"]
        end

        def hints = '↑↓ choose   H hide/show   B bar a guest for a day   TAB next   Q back'

        def hide(note)
          return unless note

          op = note['hidden_at'] ? :unhide : :hide
          UI::Sysop.walls(session, op, id: note['id'], reason: 'sysop')
          @notice = "#{look.accent}##{note['id']} #{op == :hide ? 'hidden' : 'shown again'}.#{RESET}"
        end

        def bar(note)
          return unless note
          return (@notice = "#{DIM}Only a guest's line can be barred; ban an account on ACCOUNTS.#{RESET}") unless note['guest']
          return unless yes?("Bar the line of #{note['name']} from the walls for a day?")

          UI::Sysop.walls(session, :bar, id: note['id'], hours: 24)
          @notice = "#{look.accent}Barred for a day.#{RESET}"
        end
      end
    end
  end
end
