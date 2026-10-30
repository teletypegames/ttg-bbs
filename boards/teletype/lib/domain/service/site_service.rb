# frozen_string_literal: true

class SiteService
  def initialize(repo) = @repo = repo

  def upcoming_events(n = 3)
    now = Time.now
    @repo.events.select { |e| e.date >= now }.sort_by(&:date).first(n)
  end

  def members = @repo.members
  def howtos  = @repo.howtos

  def blog_posts(n = 5) = @repo.blog_posts.first(n)
end
