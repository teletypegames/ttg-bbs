# frozen_string_literal: true

class SiteService
  def initialize(repo) = @repo = repo

  def upcoming_events(n = 3)
    now = Time.now
    @repo.events.select { |e| e.date >= now }.sort_by(&:date).first(n)
  end

  def members = @repo.members
end
