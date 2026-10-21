# frozen_string_literal: true

# Tiny in-memory chat hub. Each session subscribes to receive broadcast
# messages from other sessions. Backed by a per-session Queue so the
# Application's idle tick can drain pending messages.
class ChatService
  ChatLine = Struct.new(:timestamp, :username, :text)

  def initialize
    @subs = {}
    @mu   = Mutex.new
    @history = []
    @history_limit = 200
  end

  def subscribe(session_id)
    @mu.synchronize do
      @subs[session_id] = Queue.new
      @history.last(50).each { |line| @subs[session_id] << line }
    end
  end

  def unsubscribe(session_id)
    @mu.synchronize { @subs.delete(session_id) }
  end

  def broadcast(username, text)
    line = ChatLine.new(Time.now.strftime('%H:%M:%S'), username, text)
    @mu.synchronize do
      @history << line
      @history.shift while @history.size > @history_limit
      @subs.each_value { |q| q << line }
    end
    line
  end

  # Returns Array<ChatLine> of pending messages for the given session.
  def drain(session_id)
    queue = @mu.synchronize { @subs[session_id] }
    return [] unless queue
    pending = []
    pending << queue.pop(true) until queue.empty?
    pending
  rescue ThreadError
    pending
  end

  def history(n = 50)
    @mu.synchronize { @history.last(n).dup }
  end

  def subscriber_count
    @mu.synchronize { @subs.size }
  end
end
