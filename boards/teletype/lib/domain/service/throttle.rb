# frozen_string_literal: true

# At most +limit+ events per +per+ seconds for a name and, apart, for the
# line it calls from (Rubbs::Common::Line::RateLimit.caller_key): redialling does not reset
# the line's count, and another line does not reset the name's.
# Anonymous is everyone's name, so only its line is counted. With a
# +store+ (the board's Sequel::Database) the counts are kept there under +name+,
# so a restart does not reset them either.
class Throttle
  def initialize(limit:, per:, store: nil, name: nil)
    @names   = Rubbs::Common::Line::RateLimit.new(limit: limit, per: per, store: store, name: store && "#{name} by name")
    @callers = Rubbs::Common::Line::RateLimit.new(limit: limit, per: per, store: store, name: store && "#{name} by line")
  end

  # Whether one more event may happen now; it is counted when it may.
  def allow?(name, caller_key) = Rubbs::Common::Line::RateLimit.allow_all?(checks(name, caller_key))

  # The [limit, key] pairs of an event, for Rubbs::Common::Line::RateLimit.allow_all? with
  # other limits.
  def checks(name, caller_key)
    key = Rubbs::Common::Auth::Names.key(name)
    [[@callers, caller_key.to_s], *(unless key.empty? || key == Rubbs::Common::Auth::Names.key(MemberService::ANONYMOUS)
                                      [[@names, key]]
                                    end)]
  end
end
