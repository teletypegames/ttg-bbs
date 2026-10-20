# frozen_string_literal: true

# A call is logged when it ends, and only if it was a real one: a terminal
# that reported its window size and stayed at least MIN_SECONDS. Telnet
# password-guessing bots connect, type "root" and hang up, so they never
# reach the list.
class LastCallersService
  MIN_SECONDS = 10

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
    return if Time.now - started < MIN_SECONDS

    @repo.record(username, session_id)
  end

  def recent(n = 10) = @repo.recent(n)
end
