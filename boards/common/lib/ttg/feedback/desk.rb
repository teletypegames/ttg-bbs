# frozen_string_literal: true

module TTG
  module Feedback
    # The sysops' desk on either face (a TTG::Screen): the feedback of every
    # board, the new ones first (or all of them), a line each — the board, the
    # kind, who and the subject —; one taken is read whole (and so marked read)
    # and marked done or spam, set new again or deleted. The Central checks the
    # sysop role on every step, so a caller without it only hears that the
    # desk is for the sysops.
    #
    #   TTG::Feedback.desk(session)
    class Desk
      # Feedback on one screen of the list.
      PAGE = { modern: 12, petscii: 9 }.freeze
      # What a step on a feedback item does: the menu label and the state it
      # sets (D, S, U; X deletes).
      MARKS = [%w[Done done], %w[Spam spam], ['Unread again', 'new']].freeze

      # The desk for the caller on +session+.
      def initialize(session)
        @screen  = TTG::Screen.new(session)
        @session = session
        @state   = 'new'
      end

      # Runs the desk until the caller goes back. Returns +nil+.
      def run
        loop do
          answer = ask(:list, state: @state, limit: page)
          return refused(answer['result']) unless answer['items']

          choice = @screen.menu(list_items(answer['items']))
          case choice
          when Integer then item(choice)
          when :toggle then @state = @state ? nil : 'new'
          else return nil
          end
        end
      end

      private

      def page = PAGE.fetch(@screen.petscii? ? :petscii : :modern)

      def ask(op, **fields) = Feedback.box.call(op, Rubbs::Common::Central::Actor.of(@session), **fields)

      def list_items(items)
        counts = ask(:counts)['counts'] || {}
        which  = @state ? 'The new ones:' : 'All of them, newest first:'
        @screen.head('Feedback desk', "#{counts.fetch('new', 0)} new, #{counts.values.sum} in all. #{which}")
        @screen.paragraph('Nothing here.', :meta) if items.empty?
        [*items.each_with_index.map { |entry, i| [label(entry, i), entry['id'], i < 9 ? (i + 1).to_s : false] },
         [@state ? 'All of them' : 'Only the new ones', :toggle], ['Back', :back]]
      end

      def label(entry, index)
        board = entry['board'].to_s.delete_suffix('-bbs')
        about = entry['subject'].to_s.empty? ? entry['body'].to_s.tr("\n", ' ') : entry['subject']
        "#{index + 1} #{board} #{entry['kind']} #{Feedback.sender(entry)}: #{about}"[0, @screen.cols - 6]
      end

      def item(id)
        entry = ask(:read, id: id)['item'] or return @screen.tell('That feedback is gone.', :bad)

        show(entry)
        act(entry)
      end

      def show(entry)
        @screen.head("Feedback ##{entry['id']}")
        @screen.line("#{Feedback.sender(entry)} on #{entry['board']} · #{entry['kind']} · #{entry['created_at']}", :meta)
        facts(entry)
        @screen.blank
        entry['body'].to_s.split("\n").each { |line| @screen.paragraph(line) }
        @screen.blank
      end

      def facts(entry)
        @screen.line("About: #{entry['context']}", :meta) if entry['context']
        @screen.line("Link: #{entry['link']}", :meta) if entry['link']
        @screen.line(entry['subject'], :name) unless entry['subject'].to_s.empty?
      end

      def act(entry)
        choice = @screen.menu([*MARKS, ['Delete', :delete, 'x'], ['Back', :back]])
        case choice
        when String then ask(:mark, id: entry['id'], state: choice)
        when :delete then ask(:delete, id: entry['id'])
        end
      end

      def refused(result)
        text = if result == 'forbidden' then 'The feedback desk is for the sysops.'
               else 'The feedback cannot be reached now. Please try again later.'
               end
        @screen.head('Feedback desk')
        @screen.tell(text, :bad)
        nil
      end
    end
  end
end
