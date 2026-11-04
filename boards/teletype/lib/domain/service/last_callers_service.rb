# frozen_string_literal: true

# A call is logged when it ends, and only if it was a real one: a terminal
# that reported its window size and stayed at least MIN_SECONDS. Telnet
# password-guessing bots connect, type "root" and hang up, so they never
# reach the list. The log is also the board's history: caller numbers, a
# name's calls and the top callers come from it.
class LastCallersService
  MIN_SECONDS = 10

  def initialize
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

    CallModel.record(username, session_id, seconds)
  end

  def recent(n = 10) = CallModel.recent(n)

  # The number this call gets: every logged call before it, plus one.
  def caller_number = CallModel.count + 1

  def total_calls = CallModel.count

  def calls_today = CallModel.count_since(Time.now.strftime('%Y-%m-%d'))

  # The logged calls of a name (calls, first_call, last_call, seconds);
  # nil before its first one.
  def user_stats(username) = CallModel.stats(username)

  # {name key => stats} of every name that called.
  def all_stats = CallModel.all_stats

  # [[name, calls], ...] most calls first, Anonymous left out.
  def top_callers(n = 10) = CallModel.top(n, except: AccountService::ANONYMOUS)
end
