# frozen_string_literal: true

# The nodes of the board: who is on which line since when, doing what.
# A caller gets the lowest free node number, as on a multi-line BBS.
class OnlineUsersRepository
  Node = Struct.new(:number, :session_id, :name, :since, :activity)

  def initialize
    @nodes = {}
    @mu    = Mutex.new
  end

  def add(session_id, name)
    @mu.synchronize do
      taken  = @nodes.values.map(&:number)
      number = (1..).find { |n| !taken.include?(n) }
      @nodes[session_id] = Node.new(number, session_id, name, Time.now, 'Logging on')
    end
  end

  def remove(session_id)
    @mu.synchronize { @nodes.delete(session_id) }
  end

  def activity(session_id, text)
    @mu.synchronize { @nodes[session_id]&.activity = text }
  end

  def find(session_id)
    @mu.synchronize { @nodes[session_id]&.dup }
  end

  def snapshot
    @mu.synchronize { @nodes.values.map(&:dup).sort_by(&:number) }
  end

  def count
    @mu.synchronize { @nodes.size }
  end
end
