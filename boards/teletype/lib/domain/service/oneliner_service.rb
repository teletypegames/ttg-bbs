# frozen_string_literal: true

# The oneliners wall: a line of MAX_LENGTH from a name, one in COOLDOWN
# seconds a name and a line.
class OnelinerService
  MAX_LENGTH = 64
  COOLDOWN   = 30

  # +store+ is the BBS::SQLite the cooldown is kept in; nil keeps it in
  # memory.
  def initialize(repo, store: nil)
    @repo     = repo
    @throttle = Throttle.new(limit: 1, per: COOLDOWN, store: store, name: 'oneliner')
  end

  def recent(n = 5) = @repo.recent(n)

  # :ok, :anonymous, :empty, :too_long or :too_fast.
  def add(username, text, caller_key:)
    return :anonymous if username.to_s.casecmp?(AccountService::ANONYMOUS)

    line = BBS::Text.line(text)
    return :empty if line.empty?
    return :too_long if line.length > MAX_LENGTH
    return :too_fast unless @throttle.allow?(username, caller_key)

    @repo.append(username, line)
    :ok
  end
end
