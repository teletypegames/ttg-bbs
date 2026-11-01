# frozen_string_literal: true

class SiteService
  def initialize(repo) = @repo = repo

  def upcoming_events(n = 3)
    now = Time.now
    @repo.events.select { |e| e.date >= now }.sort_by(&:date).first(n)
  end

  # The days of a game jam around +today+ (an event named a jam within three
  # days, and the two days after it), as a Range of Date, or nil.
  def jam(today = Date.today)
    event = @repo.events.find { |e| e.name.match?(/\bjam\b/i) && (e.date.to_date - today).abs <= 3 }
    event && (event.date.to_date..(event.date.to_date + 2))
  end

  def members = @repo.members
end
