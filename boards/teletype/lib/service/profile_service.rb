# frozen_string_literal: true

class ProfileService
  def initialize(repo) = @repo = repo

  def find(username)        = @repo.find(username)
  def update(username, **f) = @repo.upsert(username: username, **f)
end
