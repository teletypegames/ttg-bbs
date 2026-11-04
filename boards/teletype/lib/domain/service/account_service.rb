# frozen_string_literal: true

# Who may use which name. Anonymous and malformed names never register;
# sysop names are created only from the server shell (bin/account), so a
# caller cannot claim one first over telnet; nor can anyone take a name
# that looks like a registered or a sysop one (Names.skeleton).
class AccountService
  NAME_PATTERN = /\A[\p{L}\p{N}][\p{L}\p{N} ._-]{0,19}\z/
  MIN_PASSWORD = 6
  ANONYMOUS    = 'Anonymous'
  # Password prompts in one call, and the pause after a wrong one (times
  # the attempt).
  TRIES        = 3
  WRONG_PAUSE  = 2

  def initialize(reserved: [], guard: LoginGuard.new, pause: ->(seconds) { sleep seconds })
    @reserved = reserved.map { |name| Names.skeleton(name) }
    @guard    = guard
    @pause    = pause
  end

  def self.normalize_name(raw)
    name = BBS::Text.utf8(raw).strip.gsub(/\s+/, ' ')
    name.match?(NAME_PATTERN) ? name : ANONYMOUS
  end

  def registered?(name)   = !AccountModel.named(name).nil?
  def names               = AccountModel.names
  def created_at(name)    = AccountModel.named(name)&.created_at

  # The registered spelling of a name typed in any case, nil when unknown.
  def canonical(name) = AccountModel.named(name)&.name

  # The logon of +name+ from the line +caller_key+. The block is asked
  # for the password (given true when the one before was wrong) and
  # returns it, or nil when the line dropped. Answers :ok, :guest (a name
  # nobody registered), :look_alike (too like a registered one), :locked
  # (too many wrong passwords of late), :wrong (TRIES of them) or :dropped.
  def log_on(name, caller_key:, &ask)
    return AccountModel.look_alike(name) ? :look_alike : :guest unless registered?(name)

    TRIES.times do |attempt|
      result = try_password(name, caller_key, attempt, &ask)
      return result if result
    end
    :wrong
  end

  def register(name, password, confirm)
    problem = registration_problem(name, password, confirm)
    return problem if problem

    salt = Password.salt
    AccountModel.register(name, salt, Password.digest(password, salt))
  end

  # Server-side: create or reset any account, sysops included.
  def set_password(name, password)
    return :too_short if password.to_s.length < MIN_PASSWORD

    salt = Password.salt
    AccountModel.set_password(name, salt, Password.digest(password, salt))
    :ok
  end

  private

  def try_password(name, caller_key, attempt)
    return :locked if @guard.locked?(name, caller_key)

    password = yield(attempt.positive?)
    return :dropped if password.nil?
    return :ok if authentic?(name, password)

    @guard.record_failure(name, caller_key)
    @pause.call(WRONG_PAUSE * (attempt + 1))
    nil
  end

  def authentic?(name, password)
    account = AccountModel.named(name)
    !account.nil? && Password.match?(password, account.salt, account.digest)
  end

  def registration_problem(name, password, confirm)
    return :anonymous  if name.to_s.casecmp?(ANONYMOUS)
    return :reserved   if @reserved.include?(Names.skeleton(name))
    return :taken      if registered?(name)
    return :look_alike if AccountModel.look_alike(name)
    return :too_short  if password.to_s.length < MIN_PASSWORD

    :mismatch unless password == confirm
  end
end
