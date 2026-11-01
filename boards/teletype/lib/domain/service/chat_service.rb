# frozen_string_literal: true

# Tiny in-memory chat hub. Each session subscribes to receive broadcast
# messages from other sessions. Backed by a per-session list so the
# Application's idle tick can drain pending messages; a session that does
# not read its chat keeps only the latest PENDING_LIMIT lines.
class ChatService
  ChatLine = Struct.new(:timestamp, :username, :text)

  PENDING_LIMIT = 200
  MIN_INTERVAL  = 0.5

  def initialize
    @subs = {}
    @last = {}
    @mu   = Mutex.new
    @history = []
    @history_limit = 200
    @said_at = nil
  end

  def subscribe(session_id)
    @mu.synchronize { @subs[session_id] = [] }
  end

  # False when the session spoke less than MIN_INTERVAL seconds ago.
  def may_speak?(session_id)
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @mu.synchronize do
      return false if @last[session_id] && now - @last[session_id] < MIN_INTERVAL

      @last[session_id] = now
      true
    end
  end

  def unsubscribe(session_id)
    @mu.synchronize do
      @subs.delete(session_id)
      @last.delete(session_id)
    end
  end

  def broadcast(username, text)
    line = ChatLine.new(Time.now.strftime('%H:%M:%S'), username, text)
    @mu.synchronize do
      @said_at = Time.now
      @history << line
      @history.shift while @history.size > @history_limit
      @subs.each_value do |pending|
        pending << line
        pending.shift while pending.size > PENDING_LIMIT
      end
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
end
