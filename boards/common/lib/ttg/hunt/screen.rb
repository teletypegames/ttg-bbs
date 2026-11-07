# frozen_string_literal: true

module TTG
  module Hunt
    # The caller's hunt, on either face (TTG::Screen): the clue of the step
    # they are on, the fragments they found, the hints they saw, and the
    # answer box; the list of the week, and the hunts of past weeks, which
    # can still be played. A guest reads the first clue.
    class Screen
      # What a guest is told under the first clue.
      GUEST = 'Callers with an account play The Hunt: the steps, the fragments, a place on the list and a badge. ' \
              'Make one in your profile: a name and a password, nothing more.'

      # The caller's hunt on +session+: +hunt+ (a slug), or the one in season.
      def initialize(session, hunt: nil)
        @session = session
        @screen  = TTG::Screen.new(session)
        @hunt    = hunt
      end

      # Shows the hunt until the caller goes back. Returns +nil+.
      def run
        loop do
          state = fetch or return nil
          show(state)
          choice = @screen.menu(items(state))
          return nil unless %i[answer hint list past].include?(choice)

          act(choice, state)
        end
      end

      private

      def proxy = Hunt.proxy

      def actor = Rubbs::Common::Central::Actor.of(@session)

      def fetch
        state = proxy.state(actor, hunt: @hunt)
        return state if state['trail']

        message = state['result'] == 'no_hunt' ? 'No hunt is open yet. Come back on Monday.' : 'The Hunt cannot be reached now.'
        @screen.tell(message, :bad)
        nil
      end

      def act(choice, state)
        slug = state['trail']['slug']
        case choice
        when :answer then answer(slug)
        when :hint then hint(slug)
        when :list then list(state['trail'])
        else past
        end
      end

      def show(state)
        trail = state['trail']
        @screen.head("The Hunt: #{trail['title']}", heading(state))
        intro = state['step'] == 1 && !trail['intro'].to_s.empty?
        prose(trail['intro'], :meta) if intro
        @screen.blank if intro
        state['finish'] ? finished(state) : clue(state)
        @screen.blank
      end

      def heading(state)
        trail = state['trail']
        until_ = day(trail['closes'])
        when_  = "closed on #{until_}, off the list"
        when_  = "open until #{until_} · #{trail['players']} on the trail, #{trail['finished']} home" if trail['season']
        return "Finished · #{when_}" if state['finish']

        "Step #{state['step']} of #{state['steps']} · #{when_}"
      end

      def prose(text, role)
        text.to_s.strip.split(/\n\s*\n/).each_with_index do |part, i|
          @screen.blank if i.positive?
          @screen.paragraph(part.split.join(' '), role)
        end
      end

      def day(epoch)
        Rubbs::Common::Season.now(tz: Rubbs::Common::Hunt.time_zone, at: Time.at(epoch.to_i - 1)).time.strftime('%-d %b')
      end

      def clue(state)
        prose(state['clue'], :text)
        @screen.blank
        fragments(state['fragments'])
        Array(state['hints']).each_with_index { |text, i| prose("Hint #{i + 1}: #{text}", :meta) }
        @screen.line(next_hint(state['next_hint_at']), :meta) if state['next_hint_at']
        @screen.paragraph(state['asks'] ? 'Answer it here.' : 'Go and find it on the network.', :meta) unless state['guest']
        @screen.paragraph(GUEST, :name) if state['guest']
      end

      def fragments(list)
        @screen.line("Fragments: #{list.join(' · ')}", :good) if list&.any?
      end

      def finished(state)
        finish = state['finish']
        fragments(state['fragments'])
        place = finish['rank'] ? ", number #{finish['rank']} on the list" : ''
        hints = finish['hints'] == 1 ? '1 hint' : "#{finish['hints']} hints"
        @screen.paragraph("You made it home in #{span(finish['seconds'])}, #{hints}#{place}.", :good)
      end

      def next_hint(at)
        left = at.to_i - Time.now.to_i
        left.positive? ? "The next hint comes in #{span(left)}." : 'A hint is waiting.'
      end

      def span(seconds)
        seconds = seconds.to_i
        days, rest = seconds.divmod(86_400)
        hours, rest = rest.divmod(3600)
        return "#{days} d #{hours} h" if days.positive?
        return "#{hours} h#{" #{rest / 60} min" if rest >= 60}" if hours.positive?

        "#{[rest / 60, 1].max} min"
      end

      def items(state)
        items = []
        playing = !state['guest'] && !state['finish']
        items << ['Answer', :answer] if playing && state['asks']
        items << ['Hint', :hint] if playing && state['next_hint_at'] && state['next_hint_at'].to_i <= Time.now.to_i
        items << ['The list', :list, 'l']
        items << ['Past hunts', :past]
        items << ['Back', :back]
      end

      def answer(slug)
        text = @screen.ask('Your answer') or return
        reply = proxy.answer(actor, hunt: slug, text: text)
        case reply['result']
        when 'right' then @screen.tell(['Right!', *reply['notices']].join(' '), :good)
        when 'wrong' then @screen.tell('Not that. Try again in half a minute.', :bad)
        when 'wait' then @screen.tell("Wait #{reply['seconds']} seconds before the next answer.", :bad)
        else @screen.tell('That cannot be answered now.', :bad)
        end
      end

      def hint(slug)
        reply = proxy.hint(actor, hunt: slug)
        return @screen.tell("Hint: #{reply['hint']}", :name) if reply['hint']

        @screen.tell(reply['at'] ? next_hint(reply['at']) : 'No more hints for this step.', :meta)
      end

      def list(trail)
        rows = proxy.board(hunt: trail['slug'])['board'] or return @screen.tell('The list cannot be reached now.', :bad)

        @screen.head("The Hunt: #{trail['title']}", 'Who made it home while it was open: fewest hints first, then the fastest.')
        @screen.paragraph('Nobody yet.', :meta) if rows.empty?
        rows.each_with_index do |row, i|
          hints = row['hints'] == 1 ? '1 hint' : "#{row['hints']} hints"
          @screen.line("#{i + 1}. #{row['name']}  #{span(row['seconds'])}  #{hints}", :text)
        end
        @screen.blank
        @screen.pause
      end

      def past
        trails = proxy.trails['past'] or return @screen.tell('The Hunt cannot be reached now.', :bad)
        return @screen.tell('There are no past hunts yet.', :meta) if trails.empty?

        @screen.head('Past hunts', 'Every hunt can still be played; its list stays as it was when it closed.')
        choice = @screen.menu(trails.first(9).each_with_index.map { |t, i| ["#{i + 1} #{t['title']}", t['slug'], (i + 1).to_s] })
        @hunt = choice unless choice == :back || choice.nil?
      end
    end
  end
end
