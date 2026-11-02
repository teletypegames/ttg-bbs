# frozen_string_literal: true

# Tiny in-memory chat hub. Each session subscribes to receive broadcast
# messages from other sessions. Backed by a per-session list so the
# Application's idle tick can drain pending messages; a session that does
# not read its chat keeps only the latest PENDING_LIMIT lines. A caller
# speaks through #say: a line of MAX_LENGTH at most, BURST of them in
# BURST_SECONDS a name and a line.
class ChatService
  ChatLine = Struct.new(:timestamp, :username, :text)

  PENDING_LIMIT = 200
  HISTORY_LIMIT = 200
  MAX_LENGTH    = 240
  BURST         = 4
  BURST_SECONDS = 4

  def initialize
    @subs     = {}
    @mu       = Mutex.new
    @history  = []
    @said_at  = nil
    @throttle = Throttle.new(limit: BURST, per: BURST_SECONDS)
  end

  def subscribe(session_id)
    @mu.synchronize { @subs[session_id] = [] }
  end

  def unsubscribe(session_id)
    @mu.synchronize { @subs.delete(session_id) }
  end

  # A caller's line: :ok, :empty or :too_fast.
  def say(username, text, caller_key:)
    line = BBS::Text.line(text)[0, MAX_LENGTH]
    return :empty if line.empty?
    return :too_fast unless @throttle.allow?(username, caller_key)

    broadcast(username, line)
    :ok
  end

  # A line from the board itself (a page, a sysop broadcast, IRC).
  def broadcast(username, text)
    line = ChatLine.new(Time.now.strftime('%H:%M:%S'), username, text)
    @mu.synchronize do
      @said_at = Time.now
      push(@history, line, HISTORY_LIMIT)
      @subs.each_value { |pending| push(pending, line, PENDING_LIMIT) }
    end
    line
  end

  # Returns Array<ChatLine> of pending messages for the given session.
  def drain(session_id)
    @mu.synchronize { @subs[session_id]&.slice!(0..) || [] }
  end

  def history(n = 50)
    @mu.synchronize { @history.last(n).dup }
  end

  # When the last line was said, or nil before the first: the smoke from
  # the clubhouse chimney.
  def said_at
    @mu.synchronize { @said_at }
  end

  def subscriber_count
    @mu.synchronize { @subs.size }
  end

  private

  def push(list, line, limit)
    list << line
    list.shift while list.size > limit
  end
end
