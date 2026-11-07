# frozen_string_literal: true

module UI
  # The caller's account on the gate, the same on both faces (the modern
  # UI::Modern::ProfileTab and the C64's UI::Petscii::Views::ProfileView):
  # what they can do (#items), and doing it. A face gives the way it reads a
  # line (+ask+: label, mask:, hint: → the text or +nil+) and tells a result
  # (+say+: text, good → nothing); a place the boards added to the profile
  # (Rubbs::Common::Auth::Profile.extra) takes the screen, so the face runs
  # it (#extra). Logging in is rubbs' Rubbs::Common::Auth::Login.
  class Account
    # An item of the profile: its +key+, the +label+, the +letter+ that takes
    # it, and the line it is +about+.
    Item = Data.define(:key, :label, :letter, :about)

    # What each item does, by key.
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
    # The items that are the account's own (the rest are the boards' places).
    OWN = %i[log_in register password log_out].freeze
    # Seconds the badges and the hunt are kept before they are asked again.
    KEEP = 30

    # The account of the caller on +session+; +ask+ and +say+ as above.
    def initialize(session, ask:, say:)
      @session = session
      @ask     = ask
      @say     = say
      @facts   = nil
    end

    # The caller's items (Item): their own first (log in and a new account,
    # or the password and logging out), then the places of the profile they
    # see.
    def items
      own = identity.signed_in? ? [own_item(:password, 'Change password', 'c'), own_item(:log_out, 'Log out', 'l')] : guest_items
      own + extras.map { |e| Item.new(key: e.key, label: e.label, letter: e.hotkey, about: ABOUT.fetch(e.key, '')) }
    end

    # Whether +item+ is the account's own (done here) rather than a place.
    def own?(item) = OWN.include?(item.key)

    # Does the account's own +item+ (#own?). Returns +nil+.
    def take(item)
      send(item.key) if own?(item)
      nil
    end

    # The place of +item+ (a Rubbs::Common::Auth::Profile::Extra), for the
    # face to run, or +nil+.
    def extra(item) = extras.find { |e| e.key == item.key }

    # Who the caller is: their name (or +nil+ for a guest) and their roles.
    def who = identity.signed_in? ? [identity.name.to_s, identity.roles.to_a] : [nil, []]

    # The caller's badges and hunt, [label, words] each, asked at most every
    # KEEP seconds; none for a guest or without the Central.
    def facts
      return [] unless identity.signed_in? && Rubbs.config.central

      now = Time.now.to_i
      @facts = nil if @facts_for != identity.id || (@facts_at && now - @facts_at >= KEEP)
      @facts_for = identity.id
      @facts_at = now if @facts.nil?
      @facts ||= [badges, hunt].compact
    end

    # Forgets the facts (after a place, where a badge may have come).
    def refresh = @facts = nil

    private

    def identity = @session.identity

    def setup = Rubbs.config.auth

    def words = Rubbs::Common::Auth::Profile::WORDS

    def extras = Rubbs::Common::Auth::Profile.extras.select { |e| e.visible_to?(@session) }

    def own_item(key, label, letter) = Item.new(key: key, label: label, letter: letter, about: ABOUT.fetch(key))

    def guest_items = setup ? [own_item(:log_in, 'Log in', 'l'), own_item(:register, 'New account', 'n')] : []

    def actor = Rubbs::Common::Central::Actor.of(@session)

    def badges
      list = Rubbs.central(Rubbs::Common::Badges::Service).mine(actor)['badges'] or return nil
      ['Badges', "#{list.count { |b| b['earned'].any? }} of #{list.size} earned"]
    rescue StandardError
      nil
    end

    def hunt
      season = TTG::Hunt.proxy.trails['season'] or return nil
      ['The Hunt', "#{season['title']}, #{season['players']} on the trail"]
    rescue StandardError
      nil
    end

    def ask(label, mask: nil, hint: 'RETURN takes it, RUN/STOP or Esc gives it up.') = @ask.call(label, mask: mask, hint: hint)

    def good(text) = @say.call(text, true)

    def bad(text) = @say.call(text, false)

    def log_in
      found = Rubbs::Common::Auth::Login.new(setup, @session, ask: method(:ask), tell: method(:bad)).run or return
      refresh
      good(format(words[:welcome], name: found.name))
    end

    def register
      name = ask('name', hint: 'Letters and digits, at most 20.') or return
      least = Rubbs::Common::Auth::Directory::MIN_PASSWORD
      password = ask('password', mask: '*', hint: "At least #{least} characters.") or return
      again = ask('again', mask: '*', hint: 'The same password once more.').to_s
      found = setup.directory.register(name, password, again)
      return bad(words.fetch(found, words[:unavailable])) unless found.is_a?(Rubbs::Common::Auth::Identity)

      @session.identity = found
      good(format(words[:ready], name: found.name))
    end

    def password
      old = ask('current password', mask: '*') or return
      fresh = ask('new password', mask: '*').to_s
      result = fresh == ask('again', mask: '*').to_s ? change(old, fresh) : :differ
      result == :ok ? good(words[:ok]) : bad(words.fetch(result, words[:unavailable]))
    end

    def change(old, fresh) = setup.directory.change_password(identity.name, old, fresh, caller_key: @session.caller_key)

    def log_out
      Rubbs::Common::Auth.event(:logout, name: identity.name)
      @session.identity = Rubbs::Common::Auth::Identity.guest
      good(words[:logged_out])
    end
  end
end
