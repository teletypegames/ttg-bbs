# frozen_string_literal: true

class GamesService
  def initialize(repo) = @repo = repo

  def all = @repo.fetch
end
