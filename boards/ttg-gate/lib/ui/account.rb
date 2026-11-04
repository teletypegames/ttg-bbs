# frozen_string_literal: true

module UI
  # The caller's account on the gate, the home of the accounts of the
  # network (BBS::Auth): log in, make a new account, change the password,
  # log out. A line-by-line screen on either face, handed the line by the
  # chooser (A). A caller logged in here is logged in on every board they
  # dial (BBS::Gateway hands them on with a RUBBS_AUTH_KEY).
  class Account
    # What the caller is told for the answers of BBS::Auth::Directory.
    WORDS = {
      ok:         'Done.',
      invalid:    'A name is letters and digits, at most 20.',
      reserved:   'That name is kept for the board.',
      taken:      'That name has an account. Log in with it instead.',
      look_alike: 'That name looks too much like another account.',
      too_short:  "The password needs at least #{BBS::Auth::Directory::MIN_PASSWORD} characters.",
      mismatch:   'The two passwords differ.',
      differ:     'The two new passwords differ.',
      **BBS::Auth::Login::WORDS
    }.freeze

    # Runs the account screen for the caller on +session+ with +accounts+ (a
    # BBS::Auth::Directory) until they go back. Raises BBS::Hangup when they
    # hang up.
    def self.run(session, accounts) = new(session, accounts).run

    # The screen for +session+.
    def initialize(session, accounts)
      @session  = session
      @accounts = accounts
      @runner   = BBS::FlowRunner.new(session, session.session_id, BBS::Flow.new)
    end

    # Shows who the caller is and what they can do, until RETURN alone.
    def run
      loop do
        show
        key = @session.readkey
        raise BBS::Hangup if key.nil?
        return unless stay_after?(key.to_s.downcase)
      end
    end

    private

    def identity = @session.identity

    def show
      write BBS::Ansi::CLEAR
      line '', 'YOUR ACCOUNT', ''
      if identity.signed_in?
        line "Logged in as #{identity.name} (#{identity.roles.join(', ')}).",
             'The boards you dial from here know you.',
             '',
             'P  change password',
             'O  log out'
      else
        line 'One account for every Teletype Games board.', '', 'L  log in', 'N  new account'
      end
      line 'RETURN  back to the gate'
    end

    # Does what +key+ says; false when it is the way back.
    def stay_after?(key)
      case [key, identity.signed_in?]
      when ['l', false] then log_in
      when ['n', false] then register
      when ['p', true]  then password
      when ['o', true]  then @session.identity = BBS::Auth::Identity.guest
      else return !%w[enter escape q].include?(key)
      end
      true
    end

    def log_in
      setup = BBS::Auth::Setup.new(directory: @accounts, login: :menu, guests: true)
      found = BBS::Auth::Login.new(setup, @session, ask: method(:ask), tell: method(:tell)).run
      tell("Welcome, #{found.name}.") if found
      pause
    end

    def register
      name = ask('name') or return
      password = ask('password', mask: '*') or return
      result = @accounts.register(name, password, ask('again', mask: '*').to_s)
      result.is_a?(BBS::Auth::Identity) ? welcome(result) : tell(WORDS.fetch(result, WORDS[:unavailable]))
      pause
    end

    def welcome(found)
      @session.identity = found
      tell("Welcome, #{found.name}. Your account is ready.")
    end

    def password
      old = ask('current password', mask: '*') or return
      fresh = ask('new password', mask: '*').to_s
      result = fresh == ask('again', mask: '*') ? change(old, fresh) : :differ
      tell(WORDS.fetch(result, WORDS[:unavailable]))
      pause
    end

    def change(old, fresh) = @accounts.change_password(identity.name, old, fresh, caller_key: @session.caller_key)

    def ask(label, mask: nil)
      answer = @runner.ask("  #{label}: ", mask: mask)
      raise BBS::Hangup if answer.nil?

      answer.empty? ? nil : answer
    end

    def tell(text) = @runner.line(text, style: :error)

    def line(*texts) = texts.each { |text| @runner.line(text, style: :muted) }

    def write(text) = @runner.write(text)

    def pause
      @runner.line('Press a key.', style: :muted)
      @session.readkey or raise BBS::Hangup
    end
  end
end
