# frozen_string_literal: true

module UI
  module Petscii
    module Sysop
      # The feedback of the network (TTG::Feedback) on a C64, newest first: a
      # row each (a dot for a new one, the board, who), under a rule the lit
      # one's kind, subject and the start of its message. RETURN reads it
      # whole (and marks it read), D done, S spam, U new, X deletes it.
      class FeedbackView < Views::Picker
        include Shared

        PER_PAGE = 8
        HINT = [['RETURN', true], [' Read ', false], ['D', true], ['one ', false], ['S', true], ['pam ', false],
                ['X', true], [' Del ', false], ['←', true]].freeze

        every(10) { redraw }

        key('d', 'D') { guarded { mark(selected, 'done') } }
        key('s', 'S') { guarded { mark(selected, 'spam') } }
        key('u', 'U') { guarded { mark(selected, 'new') } }
        key('x', 'X') { guarded { delete(selected) } }

        def initialize(_accounts)
          super([], per_page: PER_PAGE)
        end

        def section = :feedback

        def hint = HINT

        def take(item) = guarded { read(item) }

        def draw(canvas)
          reload_items(UI::Sysop.feedback(session, :list, limit: 100)['items'] || [])
          Layout.band(canvas, 'FEEDBACK', "#{items.count { |i| i['state'] == 'new' }} new  #{page_mark}", Canvas::YELLOW)
          on_page.each_with_index { |item, slot| row(canvas, item, slot) }
          detail(canvas, selected)
        end

        private

        def row(canvas, item, slot)
          list_row(
            canvas,
            Layout.row(1 + slot),
            slot,
            UI::Sysop.sender(item),
            item['board'].to_s.delete_suffix('-bbs')[0, 9],
            mark: item['state'] == 'new' ? '*' : nil
          )
        end

        def detail(canvas, item)
          top = Layout.row(1 + PER_PAGE)
          return facts(canvas, top, [['', 'No feedback.', Canvas::GREY]]) unless item

          about = item['subject'].to_s.empty? ? item['context'] : item['subject']
          facts(canvas, top, [['Kind', item['kind']], ['State', item['state']], ['About', about],
                              ['', item['body'].to_s.tr("\n", ' ')[0, 30], Canvas::WHITE]])
        end

        def read(item)
          return unless item

          full = UI::Sysop.feedback(session, :read, id: item['id'])['item'] || item
          lines = Rubbs::Modern::FrameBuffer.wrap_ansi(Layout.plain(full['body'].to_s.tr("\n", ' ')), 36).first(14)
          tell("#{UI::Sysop.sender(full)} #{full['kind']}", full['subject'].to_s, '', *lines)
        end

        def mark(item, state)
          UI::Sysop.feedback(session, :mark, id: item['id'], state: state) if item
        end

        def delete(item)
          return unless item && yes?("Delete feedback ##{item['id']}?")

          UI::Sysop.feedback(session, :delete, id: item['id'])
        end
      end
    end
  end
end
