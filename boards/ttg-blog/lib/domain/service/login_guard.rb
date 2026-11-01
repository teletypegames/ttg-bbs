# frozen_string_literal: true

# What stands between a password guesser and the editors: failed logins
# are counted by the name tried and by the caller (BBS::RateLimit.caller_key,
# so hanging up and calling again does not start over), and either one
# locks for a while after too many. The key derivations run at most +slots+
# at a time, so a flood of tries cannot take the one CPU from the readers.
class LoginGuard
  WINDOW = 15 * 60

  def initialize(per_name: 10, per_caller: 5, window: WINDOW, slots: 2, slot_wait: 5)
    @by_name   = BBS::RateLimit.new(limit: per_name, per: window)
    @by_caller = BBS::RateLimit.new(limit: per_caller, per: window)
    @slots     = Thread::SizedQueue.new(slots)
    @slot_wait = slot_wait
    slots.times { @slots << :slot }
  end

  # Seconds until +name+ and +caller+ may try again; 0.0 when they may now.
  def wait(name, caller) = [@by_name.wait(name_key(name)), @by_caller.wait(caller)].max

  def locked?(name, caller) = wait(name, caller).positive?

  # Counts a failed try against both.
  def failed(name, caller)
    @by_name.allow?(name_key(name))
    @by_caller.allow?(caller)
    nil
  end

  # The block's value, run when a slot is free; :busy when none came free
  # in time.
  def derive
    slot = @slots.pop(timeout: @slot_wait)
    return :busy unless slot

    begin
      yield
    ensure
      @slots << slot
    end
  end

  private

  def name_key(name) = "name:#{name.to_s.strip.downcase}"
end
