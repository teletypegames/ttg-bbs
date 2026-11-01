# frozen_string_literal: true

# At most +limit+ events per +per+ seconds for a name and, apart, for the
# line it calls from (BBS::RateLimit.caller_key): redialling does not reset
# the line's count, and another line does not reset the name's.
# Anonymous is everyone's name, so only its line is counted.
class Throttle
  def initialize(limit:, per:)
    @names   = BBS::RateLimit.new(limit: limit, per: per)
    @callers = BBS::RateLimit.new(limit: limit, per: per)
  end

  # Whether one more event may happen now; it is counted when it may.
  def allow?(name, caller_key)
    keys = keys(name, caller_key)
    return false unless keys.all? { |limit, key| limit.wait(key).zero? }

    keys.each { |limit, key| limit.allow?(key) }
    true
  end

  private

  def keys(name, caller_key)
    key = Names.key(name)
    [[@callers, caller_key.to_s], *([[@names, key]] unless key.empty? || key == Names.key(AccountService::ANONYMOUS))]
  end
end
