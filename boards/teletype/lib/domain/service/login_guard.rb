# frozen_string_literal: true

# Wrong passwords counted by the name tried and by the line they came
# from: past either limit the name (or the line) waits out the window
# before PBKDF2 runs for it again.
class LoginGuard
  WINDOW = 900

  def initialize(per_name: 10, per_caller: 6, window: WINDOW)
    @names   = BBS::RateLimit.new(limit: per_name, per: window)
    @callers = BBS::RateLimit.new(limit: per_caller, per: window)
  end

  def locked?(name, caller_key) = wait(name, caller_key).positive?

  # Seconds until +name+ from +caller_key+ may try again.
  def wait(name, caller_key) = [@names.wait(Names.key(name)), @callers.wait(caller_key.to_s)].max

  def record_failure(name, caller_key)
    @names.allow?(Names.key(name))
    @callers.allow?(caller_key.to_s)
    nil
  end
end
