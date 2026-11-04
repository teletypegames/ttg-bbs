# frozen_string_literal: true

# Who comes in under which name. The accounts are the network's (BBS::Auth,
# kept on TTG Gate BBS): +directory+ answers the BBS::Auth::Directory (or
# Remote) of the board, nil when it has none. A name without an account
# comes in as a guest, a blank or malformed one as ANONYMOUS, and nobody
# comes in under a look-alike of an account's name. The callers who came
# in signed in are the board's members (MemberModel).
class MemberService
  ANONYMOUS   = 'Anonymous'
  # Password prompts in one call, and the pause after a wrong one (times
  # the attempt).
  TRIES       = 3
  WRONG_PAUSE = 2

  def initialize(directory:, pause: ->(seconds) { sleep seconds })
    @directory = directory
    @pause     = pause
  end

  # +raw+ as a caller's name: trimmed, inner spaces single; ANONYMOUS when
  # it is not one an account may have (BBS::Auth::Names.clean).
  def self.normalize_name(raw) = BBS::Auth::Names.clean(raw) || ANONYMOUS

  def names            = MemberModel.names
  def created_at(name) = MemberModel.named(name)&.created_at

  # Remembers a signed-in +identity+ (a BBS::Auth::Identity) as a member.
  def remember(identity)
    MemberModel.remember(identity) if identity.signed_in?
  end

  # The spelling of a member's name typed in any case, the name as typed
  # when it has an account that never called here, nil when nobody has it.
  def canonical(name)
    return nil if name.to_s.strip.empty?

    MemberModel.named(name)&.name || (name.to_s.strip if directory&.known?(name))
  end

  # The logon of +name+ (normalize_name'd) from the line +caller_key+. The
  # block is asked for the password (given true when the one before was
  # wrong) and returns it, or nil when the line dropped. Answers the
  # BBS::Auth::Identity the caller comes in as (a named guest for a name
  # without an account), or :look_alike (too like an account's name),
  # :wrong (TRIES wrong passwords), :locked, :busy, :unavailable or
  # :dropped. When the accounts cannot be asked (the gate is away), a name
  # a member called with before still asks its password (and is turned
  # away as :unavailable), any other comes in as Anonymous: nobody gets in
  # under a name they cannot prove.
  def log_on(name, caller_key:, &ask)
    accounts = directory
    return BBS::Auth::Identity.guest(name) if name == ANONYMOUS || accounts.nil?

    state = account_state(accounts, name)
    return BBS::Auth::Identity.guest(ANONYMOUS) if state == :unavailable
    return accounts.look_alike?(name) ? :look_alike : BBS::Auth::Identity.guest(name) if state == :unknown

    TRIES.times do |attempt|
      result = try_password(accounts, name, caller_key, attempt, &ask)
      return result if result
    end
    :wrong
  end

  # A new account of +name+ with +password+ (said twice): its
  # BBS::Auth::Identity, remembered as a member, or why not (:anonymous and
  # the answers of BBS::Auth::Directory#register, or :unavailable).
  def register(name, password, confirm)
    return :anonymous if name.to_s.casecmp?(ANONYMOUS)

    result = directory&.register(name, password, confirm) || :unavailable
    remember(result) if result.is_a?(BBS::Auth::Identity)
    result
  end

  private

  def directory = @directory.call

  def account_state(accounts, name)
    state = accounts.account_state(name)
    state == :unavailable && MemberModel.named(name) ? :known : state
  end

  def try_password(accounts, name, caller_key, attempt)
    password = yield(attempt.positive?)
    return :dropped if password.nil?

    result = accounts.log_in(name, password, caller_key: caller_key)
    return result unless result == :wrong

    @pause.call(WRONG_PAUSE * (attempt + 1))
    nil
  end
end
