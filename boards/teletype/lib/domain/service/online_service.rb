# frozen_string_literal: true

class OnlineService
  def initialize(repo) = @repo = repo

  def add(session_id, username) = @repo.add(session_id, username)
  def remove(session_id)        = @repo.remove(session_id)
  def count                     = @repo.count
  def user_list                 = @repo.snapshot.sort.map { |_, name| name }
end
