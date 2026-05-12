# frozen_string_literal: true

class LastCallersService
  def initialize(repo) = @repo = repo

  def record(username, session_id) = @repo.record(username, session_id)
  def recent(n = 10)               = @repo.recent(n)
end
