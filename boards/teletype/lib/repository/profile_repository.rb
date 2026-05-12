# frozen_string_literal: true

require 'bbs'

# Persistent user profile, keyed by lower-cased username. Backed by a
# BBS::Store CSV at +path+.
class ProfileRepository
  HEADERS = %w[session_id timestamp username signature location homepage notes].freeze

  def initialize(path)
    @store = BBS::Store.new(path: path, headers: HEADERS)
    @by_name = {}
    @mu = Mutex.new
    rebuild
  end

  def upsert(username:, **fields)
    return if username.to_s.strip.empty?
    key = username.downcase
    @mu.synchronize do
      session_id = (@by_name[key] && @by_name[key]['session_id']) || "user-#{key}"
      @store.upsert(session_id: session_id, username: username, **fields)
      rebuild_locked
    end
  end

  def find(username)
    @mu.synchronize { @by_name[username.to_s.downcase] }
  end

  private

  def rebuild
    @mu.synchronize { rebuild_locked }
  end

  def rebuild_locked
    @by_name = @store.all.each_with_object({}) do |row, h|
      name = row['username'].to_s
      h[name.downcase] = row unless name.empty?
    end
  end
end
