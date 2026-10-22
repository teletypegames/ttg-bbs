# frozen_string_literal: true

# A call is logged when it ends, and only if it was a real one: a terminal
# that reported its window size and stayed at least MIN_SECONDS. Telnet
# password-guessing bots connect, type "root" and hang up, so they never
# reach the list. The log is also the board's history: caller numbers, a
# name's calls and the top callers come from it.
class LastCallersService
  MIN_SECONDS = 10

  UserStats = Struct.new(:calls, :first_call, :last_call, :seconds, keyword_init: true)

  def initialize(repo)
    @repo    = repo
    @pending = {}
    @mu      = Mutex.new
  end

  def start(username, session_id)
    @mu.synchronize { @pending[session_id] = [username, Time.now] }
  end

  def finish(session_id)
    username, started = @mu.synchronize { @pending.delete(session_id) }
    return unless username

    seconds = Time.now - started
    return if seconds < MIN_SECONDS

    @repo.record(username, session_id, seconds)
  end

  def recent(n = 10) = @repo.recent(n)

  # The number this call gets: every logged call before it, plus one.
  def caller_number = @repo.count + 1

  def total_calls = @repo.count

  def calls_today
    today = Time.now.strftime('%Y-%m-%d')
    @repo.all.count { |c| c.timestamp.start_with?(today) }
  end

  # The logged calls of a name (case-insensitive); nil before its first one.
  def user_stats(username)
    calls = @repo.all.select { |c| c.username.casecmp?(username.to_s) }
    return nil if calls.empty?

    UserStats.new(calls: calls.size, first_call: calls.first.time, last_call: calls.last.time,
                  seconds: calls.sum { |c| c.seconds.to_i })
  end

  # [[name, calls], ...] most calls first, Anonymous left out.
  def top_callers(n = 10)
    @repo.all.reject { |c| c.username.casecmp?(AccountService::ANONYMOUS) }
         .group_by { |c| c.username.downcase }
         .map { |_, calls| [calls.last.username, calls.size] }
         .sort_by { |name, count| [-count, name.downcase] }
         .first(n)
  end
end
