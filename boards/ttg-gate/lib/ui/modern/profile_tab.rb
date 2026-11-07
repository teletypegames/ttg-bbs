# frozen_string_literal: true

module UI
  module Modern
    # The PROFILE tab of the modern face, in the gate's look and among its
    # tabs (TAB goes on to Own Servers): who the caller is, their badges and
    # hunt, and a list of what they can do. A guest logs in or makes an
    # account, an account changes its password or logs out; the places the
    # boards add to every profile (Rubbs::Common::Auth::Profile.extra:
    # Feedback, the Wall, The Hunt, Badges, SysOp …) open from the list. The
    # names and passwords are read on the gate's bottom line, the passwords
    # masked. The arrows choose, RETURN or an item's letter takes it.
    class ProfileTab < Screen
      # What each item does, by key, under the list.
      ABOUT = {
        log_in:        'Log in with the name and password of your account: one account for every board of the network.',
        register:      'A name and a password, nothing more. With an account you collect badges, play The Hunt and ' \
                       'write letters on every board.',
        password:      'Change your password: the current one first, then the new one twice.',
        log_out:       'Log out and go on as a guest.',
        feedback:      'Tell us what works, what does not, and what you miss.',
        wall:          'The walls of every board: read them, and leave a note.',
        hunt:          'The Hunt: a treasure hunt across the boards of the network.',
        badges:        'Your badges, earned on every board, and the Hall of Badges.',
        sysop:         'The sysop\'s console: calls, accounts, feedback, walls, log.',
        feedback_desk: 'The feedback of every board, to answer and close.'
      }.freeze
      # Seconds the badges and the hunt are kept before they are asked again.
      KEEP = 30

      key(:up) { @index = (@index - 1) % items.size }
      key(:down) { @index = (@index + 1) % items.size }
      key(:enter) { take(items[@index]) }
      key(:tab, :right) { pages.switch }
      key(:left) { pages.switch(-1) }
      key(:escape) { quit }
      key(/\A[[:alpha:]]\z/) { |k| letter(k.downcase) }

      def initialize
        super
        @index  = 0
        @notice = nil
        @facts  = nil
      end

      def lines
        list = items
        @index = @index.clamp(0, list.size - 1)
        body = [*masthead(:profile), who, *facts, '', *list.each_with_index.map { |item, i| row(item, i == @index) }]
        room = rows - 1 - body.size - 5
        body.push('', rule, *about(list[@index], room.clamp(1, 3)), notice_line, hints)
      end

      private

      def identity = session.identity

      def setup = Rubbs.config.auth

      def words = Rubbs::Common::Auth::Profile::WORDS

      # The caller's items: [key, label, letter], their own first, then the
      # places the boards added that they see.
      def items
        own = identity.signed_in? ? [[:password, 'Change password', 'c'], [:log_out, 'Log out', 'l']] : guest_items
        extras = Rubbs::Common::Auth::Profile.extras.select { |e| e.visible_to?(session) }
        own + extras.map { |e| [e.key, e.label, e.hotkey] }
      end

      def guest_items = setup ? [[:log_in, 'Log in', 'l'], [:register, 'New account', 'n']] : []

      def who
        return "#{look.accent}#{BOLD}GUEST#{RESET}  #{TEXT}Not logged in.#{RESET}" unless identity.signed_in?

        roles = identity.roles.to_a.join(' · ')
        "#{look.accent}#{BOLD}#{plain(identity.name.to_s.upcase)}#{RESET}  #{DIM}#{plain(roles)}#{RESET}"
      end

      def row(item, lit)
        key, label, letter = item
        mark = "#{YELLOW}#{letter.upcase}#{RESET}"
        "#{lit ? "#{SELECTED}#{look.accent}▸" : ' '} #{mark}#{SELECTED if lit} #{BOLD}#{fit(label, 24)}#{RESET}" \
          "#{SELECTED if lit}#{DIM}#{fit(note(key), width - 29)}#{RESET}"
      end

      def note(key) = key == :log_out ? "#{identity.name} → guest" : ''

      def about(item, room)
        text = ABOUT.fetch(item&.first, '')
        Rubbs::Modern::FrameBuffer.wrap_ansi(text, width).first(room).map { |l| "#{TEXT}#{l}#{RESET}" }
      end

      def notice_line = @notice.to_s

      def hints = "#{DIM}↑↓ choose  RETURN or letter take  TAB tabs  Q hang up#{RESET}"

      # The caller's badges and hunt in a line each, asked at most every KEEP
      # seconds; none for a guest or without the Central.
      def facts
        return [] unless identity.signed_in? && Rubbs.config.central

        now = Time.now.to_i
        @facts = nil if @facts_for != identity.id || (@facts_at && now - @facts_at >= KEEP)
        @facts_for = identity.id
        @facts_at  = now if @facts.nil?
        @facts ||= [badges_line, hunt_line].compact
      end

      def actor = Rubbs::Common::Central::Actor.of(session)

      def badges_line
        badges = Rubbs.central(Rubbs::Common::Badges::Service).mine(actor)['badges'] or return nil
        earned = badges.count { |b| b['earned'].any? }
        "#{DIM}Badges#{RESET}    #{TEXT}#{earned} of #{badges.size} earned#{RESET}  #{DIM}B list#{RESET}"
      rescue StandardError
        nil
      end

      def hunt_line
        season = TTG::Hunt.proxy.trails['season'] or return nil
        "#{DIM}The Hunt#{RESET}  #{TEXT}#{plain(season['title'])}#{RESET}  " \
          "#{DIM}#{season['players']} on the trail, #{season['finished']} home  H open#{RESET}"
      rescue StandardError
        nil
      end

      def letter(key)
        item = items.find { |i| i[2] == key }
        return take(item) if item
        return pages.open_tab(:own) if key == 'o'
        return pages.open_tab(:today) if key == 't'

        quit if key == 'q'
      end

      def take(item)
        return unless item

        @index  = items.index(item) || @index
        @notice = nil
        key = item.first
        return send(key) if %i[log_in register password log_out].include?(key)

        extra = Rubbs::Common::Auth::Profile.extras.find { |e| e.key == key } or return
        hand_over { extra.action.call(session) }
        @facts = nil
      end

      def say(text, color = GREEN) = @notice = "#{color}#{plain(text)}#{RESET}"

      def ask(label, mask: nil, hint: 'RETURN takes it, Esc gives it up.')
        text = read_line("#{label.to_s.capitalize}:", max: 64, mask: mask, hint: hint)
        text.nil? || text.empty? ? nil : text
      end

      def log_in
        login = Rubbs::Common::Auth::Login.new(setup, session, ask: method(:ask), tell: ->(text) { say(text, RED) })
        found = login.run or return
        @facts = nil
        say(format(words[:welcome], name: found.name))
      end

      def register
        name = ask('name', hint: 'Letters and digits, at most 20.') or return
        least = Rubbs::Common::Auth::Directory::MIN_PASSWORD
        password = ask('password', mask: '*', hint: "At least #{least} characters.") or return
        again = ask('again', mask: '*', hint: 'The same password once more.').to_s
        found = setup.directory.register(name, password, again)
        return say(words.fetch(found, words[:unavailable]), RED) unless found.is_a?(Rubbs::Common::Auth::Identity)

        session.identity = found
        say(format(words[:ready], name: found.name))
      end

      def password
        old = ask('current password', mask: '*') or return
        fresh = ask('new password', mask: '*').to_s
        result = fresh == ask('again', mask: '*').to_s ? change(old, fresh) : :differ
        result == :ok ? say(words[:ok]) : say(words.fetch(result, words[:unavailable]), RED)
      end

      def change(old, fresh) = setup.directory.change_password(identity.name, old, fresh, caller_key: session.caller_key)

      def log_out
        Rubbs::Common::Auth.event(:logout, name: identity.name)
        session.identity = Rubbs::Common::Auth::Identity.guest
        @index = 0
        say(words[:logged_out])
      end
    end
  end
end
