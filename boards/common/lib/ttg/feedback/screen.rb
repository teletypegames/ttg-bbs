# frozen_string_literal: true

module TTG
  module Feedback
    # The feedback screen on either face (a TTG::Screen): the title and the
    # intro of the narrative, the kinds to choose from when there are more
    # than one, the kind's own intro, then its fields — a guest's name, a
    # link, the subject on a line, the message in the full-screen editor —,
    # and the answer of the Central in the narrative's words.
    class Screen
      # The screen for +session+ with +narrative+ (a TTG::Narrative) and
      # +context+ (what the caller was looking at, or +nil+).
      def initialize(session, narrative, context: nil)
        @screen    = TTG::Screen.new(session)
        @session   = session
        @narrative = narrative
        @context   = context
      end

      # Runs the screen; +kind+ skips the choice. Returns +nil+.
      def run(kind: nil)
        kind ||= choose or return
        story = @narrative.kind(kind)
        head(story)
        fields = ask_fields(story) or return
        answer(story, send_it(kind, fields))
        nil
      end

      private

      def petscii? = @screen.petscii?

      def text(story, key) = story.text(key, petscii: petscii?)

      def head(story)
        @screen.head(text(story, :title), text(story, :intro))
        @screen.line(format(text(story, :context), context: @context), :meta) if @context
      end

      def choose
        kinds = @narrative.kinds.keys
        return kinds.first || :feedback if kinds.size <= 1

        @screen.head(@narrative.text(:title, petscii: petscii?), @narrative.text(:intro, petscii: petscii?))
        choice = @screen.menu(kinds.map { |key| [@narrative.kind_label(key), key] } + [['Back', :back]])
        choice == :back ? nil : choice
      end

      def ask_fields(story)
        fields = { name: guest_name(story) }
        if (link = story.field(:link))
          fields[:link] = @screen.ask(link[:label])
          return nil if link[:required] && fields[:link].nil?
        end
        fields[:subject] = @screen.ask(story.field(:subject)[:label]) if story.field(:subject)
        body = story.field(:body)
        fields[:body] = @screen.edit(body[:label], max: body[:max]) or return
        fields
      end

      def guest_name(story)
        return nil if @session.identity.signed_in?

        field = story.field(:name) or return nil
        @screen.ask(field[:label])&.slice(0, field[:max] || 20)
      end

      def send_it(kind, fields)
        actor = Rubbs::Common::Central::Actor.of(@session, name: fields[:name])
        Feedback.box.call(
          :submit,
          actor,
          kind:    kind.to_s,
          subject: fields[:subject].to_s,
          body:    fields[:body].to_s,
          link:    fields[:link],
          context: @context
        )
      end

      def answer(story, result)
        key = {
          'ok'           => :thanks,
          'empty'        => :empty,
          'bad_link'     => :bad_link,
          'limited'      => :limited,
          'name_taken'   => :name_taken,
          'invalid_name' => :name_taken
        }.fetch(result['result'], :unavailable)
        @screen.head(text(story, :title))
        @screen.tell(text(story, key), key == :thanks ? :good : :bad)
      end
    end
  end
end
