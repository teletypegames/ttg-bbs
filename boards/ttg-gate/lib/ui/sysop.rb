# frozen_string_literal: true

require 'securerandom'

module UI
  # The sysop's console of the gate, on either face: the calls on the gate
  # (and hanging one up), the accounts of the network (roles, bans, a new
  # password), the feedback and the walls of every board (TTG::Feedback,
  # TTG::Wall) and the gate's log. It is the gate's own: rubbs only lends the
  # place in the caller's profile (Rubbs::Common::Auth::Profile.extra), where a caller
  # with the +sysop+ role finds SysOp.
  module Sysop
    # The role that opens the console.
    ROLE = 'sysop'

    # Whether the caller on +session+ may use the console.
    def self.allowed?(session) = session.identity.role?(ROLE)

    # The calls on the gate of the account +name+.
    def self.calls_of(name)
      key = Rubbs::Common::Auth::Names.key(name)
      Rubbs.calls.select { |call| call.caller_name && Rubbs::Common::Auth::Names.key(call.caller_name) == key }
    end

    # Hangs up +call+ for the sysop +by+, with a log line.
    def self.hang_up(call, by:)
      call.hang_up
      Rubbs.log('sysop', 'hung up', by: by, user: call.caller_name, ip: call.caller_ip.to_s)
    end

    # Hangs up the calls on the gate of the account +name+; how many.
    def self.hang_up_calls(name, by:) = calls_of(name).each { |call| hang_up(call, by: by) }.size

    # Bans the account +name+ in +accounts+ for +reason+ and hangs up its
    # calls on the gate; how many calls it had.
    def self.ban(accounts, name, by:, reason:)
      accounts.ban(name, by: by, reason: reason)
      hang_up_calls(name, by: by)
    end

    # A new random password for +name+ in +accounts+; the password.
    def self.new_password(accounts, name, by:)
      password = SecureRandom.alphanumeric(12)
      accounts.set_password(name, password)
      Rubbs.log('sysop', 'new password', by: by, user: name)
      password
    end

    # Asks the network's feedback (TTG::Feedback) for +op+ as the sysop on
    # +session+; the answer (a Hash).
    def self.feedback(session, op, **fields) = TTG::Feedback.box.call(op, Rubbs::Common::Central::Actor.of(session), **fields)

    # Asks the walls (TTG::Wall) for +op+ as the sysop on +session+; the answer.
    def self.walls(session, op, **fields) = TTG::Wall.walls.call(op, Rubbs::Common::Central::Actor.of(session), **fields)

    # Who sent a feedback +item+: the name, a guest's marked, or "a guest".
    def self.sender(item)
      return 'a guest' if item['name'].to_s.empty?

      item['account_id'] ? item['name'] : "#{item['name']} (guest)"
    end

    # Who wrote a wall +note+, a guest's marked.
    def self.writer(note) = note['guest'] ? "#{note['name']} (guest)" : note['name'].to_s

    # Whether +sysop+ is about to act on their own account +name+ (no ban,
    # no taking their own sysop role).
    def self.own?(name, sysop) = Rubbs::Common::Auth::Names.key(name) == Rubbs::Common::Auth::Names.key(sysop)

    # Puts SysOp in the profile of every sysop of the gate: the console of
    # their face (UI::Modern::Sysop, UI::Petscii::Sysop) on +accounts+.
    def self.offer(accounts)
      Rubbs::Common::Auth::Profile.extra(:sysop, 'SysOp', hotkey: 's', if: ->(session) { allowed?(session) }) do |session|
        session.petscii? ? Petscii::Sysop.run(session, accounts) : Modern::Sysop.run(session, accounts)
      end
    end
  end
end
