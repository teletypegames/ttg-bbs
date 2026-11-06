# frozen_string_literal: true

module UI
  module Modern
    module Sysop
      # The feedback of the network (TTG::Feedback), newest first, a row each:
      # its state, the board, the kind, who and the subject; under the list the
      # chosen one's facts and the start of its message. RETURN reads it whole
      # (and marks it read), D marks it done, S spam, U new again, X deletes it.
      class FeedbackTab < View
        every(10) { redraw }

        key(:up) { @index = [@index - 1, 0].max }
        key(:down) { @index = (@index + 1).clamp(0, [items.size - 1, 0].max) }
        key(:enter) { guarded { read(items[@index]) } }
        key('d', 'D') { guarded { mark(items[@index], 'done') } }
        key('s', 'S') { guarded { mark(items[@index], 'spam') } }
        key('u', 'U') { guarded { mark(items[@index], 'new') } }
        key('x', 'X') { guarded { delete(items[@index]) } }

        def initialize(accounts)
          super
          @index = 0
        end

        private

        def tab = :feedback

        def items = UI::Sysop.feedback(session, :list, limit: 100)['items'] || []

        def body
          list = items
          @index = @index.clamp(0, [list.size - 1, 0].max)
          rows = list.empty? ? ["#{DIM}No feedback.#{RESET}"] : window(list, @index, per_page) { |item, lit| row(item, lit) }
          [crumbs('FEEDBACK', "#{list.count { |i| i['state'] == 'new' }} new of #{list.size}"), *rows, '', rule,
           *detail(list[@index]), *(@notice ? ['', @notice] : [])]
        end

        def row(item, lit)
          bg      = lit ? SELECTED : ''
          state   = item['state'] == 'new' ? "#{look.accent}●" : ' '
          board   = fit(item['board'].to_s.delete_suffix('-bbs'), 12)
          subject = item['subject'].to_s.empty? ? item['body'] : item['subject']
          "#{lit ? "#{bg}#{look.accent}▸" : ' '}#{state}#{RESET}#{bg} #{TEXT}#{board} " \
            "#{DIM}#{fit(item['kind'], 10)} #{BOLD}#{fit(UI::Sysop.sender(item), 16)}#{RESET}#{bg} " \
            "#{TEXT}#{fit(subject, [width - 46, 8].max)}#{RESET}"
        end

        def detail(item)
          return [] unless item

          [fact('When', when_text(item['created_at'])), fact('State', [item['state'], item['handled_by']].compact.join(' by ')),
           *(item['context'] ? [fact('About', item['context'])] : []), *(item['link'] ? [fact('Link', item['link'])] : []),
           "#{TEXT}#{fit(item['body'].to_s.tr("\n", ' '), width)}#{RESET}"]
        end

        def hints = '↑↓ choose   RETURN read   D done   S spam   U new   X delete   TAB next   Q back'

        def read(item)
          return unless item

          full = UI::Sysop.feedback(session, :read, id: item['id'])['item'] || item
          text = full['body'].to_s.split("\n").flat_map { |l| wrap(l, width - 2) }
          tell("#{UI::Sysop.sender(full)} · #{full['board']} · #{full['kind']}", full['subject'].to_s, '', *text)
        end

        def mark(item, state)
          return unless item

          UI::Sysop.feedback(session, :mark, id: item['id'], state: state)
          @notice = "#{look.accent}##{item['id']} is #{state}.#{RESET}"
        end

        def delete(item)
          return unless item && yes?("Delete feedback ##{item['id']}?")

          UI::Sysop.feedback(session, :delete, id: item['id'])
          @notice = "#{look.accent}##{item['id']} deleted.#{RESET}"
        end

        def wrap(text, width) = Rubbs::Modern::FrameBuffer.wrap_ansi(plain(text), [width, 10].max)
      end
    end
  end
end
