# frozen_string_literal: true

class OnlineUsersRepository
  def initialize
    @users = {}
    @mu    = Mutex.new
  end

  def add(session_id, name)
    @mu.synchronize { @users[session_id] = name }
  end

  def remove(session_id)
    @mu.synchronize { @users.delete(session_id) }
  end

  def snapshot
    @mu.synchronize { @users.dup }
  end

  def count
    @mu.synchronize { @users.size }
  end
end
