# frozen_string_literal: true

module TTG
  module Wall
    # The wall on either face (a TTG::Screen): the title and the intro of the
    # narrative, the newest notes oldest first — number, name (a guest's
    # marked), when, and to whom it answers —, then a menu: write, answer a
    # note by its number, older notes, back to the newest, back.
    class Screen
      # Notes on a screen: a C64 has fewer rows.
      PAGE = { modern: 8, petscii: 4 }.freeze

      # The wall of +board+ (+:here+: this board's; +nil+: every board's) for
      # +session+ with +narrative+ (a TTG::Narrative).
      def initialize(session, narrative, board: :here)
        @screen    = TTG::Screen.new(session)
        @session   = session
        @narrative = narrative
        @board     = board
        @before    = nil
      end

      # Runs the wall until the caller goes back. Returns +nil+.
      def run
        loop do
          notes = show or return nil
          case @screen.menu(menu_items(notes))
          when :write then write
          when :reply then write(reply: true)
          when :older then @before = notes.first&.fetch('id')
          when :newer then @before = nil
          else return nil
          end
        end
      end

      private

      def say(key) = @narrative.text(key, petscii: @screen.petscii?)

      def show
        @screen.head(say(:title), say(:intro))
        answer = Wall.walls.call(:recent, nil, **Wall.board_field(@board), before: @before, limit: page)
        return @screen.tell(say(:unavailable), :bad) && nil unless answer['notes']

        notes = answer['notes']
        notes.empty? ? @screen.paragraph(say(:empty), :meta) : notes.each { |note| draw(note) }
        @screen.blank
        notes
      end

      def page = PAGE.fetch(@screen.petscii? ? :petscii : :modern)

      def draw(note)
        name = note['guest'] ? "#{note['name']} (#{say(:guest)})" : note['name'].to_s
        meta = ["##{note['id']}", name, ago(note['created_at'])]
        meta << note['board'] if @board.nil?
        meta << format(say(:answer), name: note['reply_name']) if note['reply_name']
        @screen.line(meta.join(' · '), note['sysop'] ? :title : :name)
        @screen.paragraph(note['text'], :text, indent: 1)
      end

      def menu_items(notes)
        items = [[say(:write), :write]]
        items << [say(:reply), :reply] unless notes.empty?
        items << [say(:older), :older] if notes.size >= page
        items << [say(:newer), :newer] if @before
        items << [say(:back), :back]
      end

      def write(reply: false)
        reply_to = reply ? @screen.ask(@narrative.field(:reply_to)[:label])&.delete('#') : nil
        return if reply && reply_to.nil?

        name = guest_name or return
        text = @screen.ask(@narrative.field(:text)[:label]) or return
        result = Wall.walls.call(:post, Rubbs::Common::Central::Actor.of(@session, name: name), text: text, reply_to: reply_to)
        done(result['result'])
      end

      def guest_name
        return '' if @session.identity.signed_in?

        @guest_name ||= @screen.ask(@narrative.field(:guest_name)[:label])
      end

      def done(result)
        key = { 'ok' => :thanks, 'empty' => :empty_note, 'invalid_name' => :name_taken }.fetch(result) do
          DEFAULTS.key?(result.to_s.to_sym) ? result.to_sym : :unavailable
        end
        @guest_name = nil if key == :name_taken
        @before = nil
        @screen.tell(say(key), key == :thanks ? :good : :bad)
      end

      def ago(time)
        Rubbs.duration(Time.parse(time.to_s))
      rescue ArgumentError
        ''
      end
    end
  end
end
