# frozen_string_literal: true

require 'time'

module TTG
  module PrivateMessage
    # The mailbox on either face (a TTG::Screen): the letters to the caller,
    # newest first, a new one marked; one taken is read whole (and so marked
    # read) and answered, deleted, or its writer blocked; a new letter asks
    # the account to write to, the subject on a line and the letter in the
    # full-screen editor; the sent letters are a list of their own. A guest
    # only hears that mail is for the accounts.
    class Mailbox
      # Letters on one screen of a list.
      PAGE = { modern: 12, petscii: 9 }.freeze

      # The mailbox of the caller on +session+ with +narrative+ (a TTG::Narrative).
      def initialize(session, narrative)
        @screen    = TTG::Screen.new(session)
        @session   = session
        @narrative = narrative
        @box       = :inbox
      end

      # Runs the mailbox until the caller goes back. Returns +nil+.
      def run
        return guest unless @session.identity.signed_in?

        loop do
          answer = ask(@box, limit: page)
          return away unless answer['letters']

          case (choice = @screen.menu(list(answer['letters'])))
          when Integer then letter(choice)
          when :write then write
          when :toggle then @box = @box == :inbox ? :outbox : :inbox
          else return nil
          end
        end
      end

      private

      def say(key) = @narrative.text(key, petscii: @screen.petscii?)

      def page = PAGE.fetch(@screen.petscii? ? :petscii : :modern)

      def ask(op, **fields) = PrivateMessage.mail.call(op, Rubbs::Common::Central::Actor.of(@session), **fields)

      def list(letters)
        inbox = @box == :inbox
        @screen.head(say(inbox ? :title : :sent_title), inbox ? say(:intro) : nil)
        @screen.paragraph(say(:empty), :meta) if letters.empty?
        [*letters.each_with_index.map { |entry, i| [label(entry, i), entry['id'], i < 9 ? (i + 1).to_s : false] },
         [say(:write), :write], [say(inbox ? :sent : :inbox), :toggle], [say(:back), :back]]
      end

      def label(entry, index)
        who  = @box == :inbox ? entry['from_name'] : "to #{entry['to_name']}"
        mark = @box == :inbox && entry['read_at'].nil? ? " (#{say(:unread_mark)})" : ''
        "#{index + 1} #{who}#{mark}: #{entry['subject'].to_s.empty? ? '…' : entry['subject']}"[0, @screen.cols - 6]
      end

      def letter(id)
        entry = ask(:read, id: id)['letter'] or return @screen.tell(say(:unavailable), :bad)

        show(entry)
        case @screen.menu(letter_items)
        when :reply then write(to: entry['from_name'], subject: reply_subject(entry['subject']), reply_to: entry['id'])
        when :delete then deleted(ask(:delete, id: entry['id']))
        when :block then blocked(entry['from_name'])
        end
      end

      def letter_items
        items = []
        items << [say(:reply), :reply] if @box == :inbox
        items << [say(:delete), :delete]
        items << [say(:block), :block, 'k'] if @box == :inbox
        items << [say(:back), :back]
      end

      def show(entry)
        @screen.head(say(:title))
        Stationery.sheet(entry, @screen.cols, petscii: @screen.petscii?).each { |line| @screen.raw(line) }
        @screen.blank
      end

      def write(to: nil, subject: nil, reply_to: nil)
        to ||= @screen.ask(@narrative.field(:to)[:label]) or return
        subject ||= @screen.ask(@narrative.field(:subject)[:label]).to_s
        body = @screen.edit("#{to}: #{subject}", max: @narrative.field(:body)[:max]) or return

        sent(ask(:write, to: to, subject: subject, body: body, reply_to: reply_to)['result'])
      end

      def sent(result)
        key = {
          'ok'              => :thanks,
          'empty'           => :empty_body,
          'unknown_account' => :unknown,
          'too_soon'        => :too_soon,
          'limited'         => :limited,
          'guest'           => :guest
        }.fetch(result, :unavailable)
        @screen.head(say(:title))
        @screen.film(Stationery.film(@screen.cols, petscii: @screen.petscii?), Stationery::FRAME) if key == :thanks
        @screen.tell(say(key), key == :thanks ? :good : :bad)
      end

      def deleted(answer) = @screen.tell(say(answer['result'] == 'ok' ? :deleted : :unavailable))

      def blocked(name)
        result = ask(:block, name: name)['result']
        @screen.tell(result == 'ok' ? format(say(:blocked), name: name) : say(:unavailable), result == 'ok' ? :good : :bad)
      end

      def reply_subject(subject) = subject.to_s.start_with?('Re: ') ? subject : "Re: #{subject}"[0, 60]

      def when_text(iso) = Time.parse(iso.to_s).localtime.strftime('%Y-%m-%d %H:%M')

      def guest
        @screen.head(say(:title))
        @screen.tell(say(:guest), :bad)
        nil
      end

      def away
        @screen.head(say(:title))
        @screen.tell(say(:unavailable), :bad)
        nil
      end
    end
  end
end
