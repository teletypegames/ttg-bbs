# frozen_string_literal: true

class SiteService
  def initialize(repo) = @repo = repo

  def upcoming_events(n = 3)
    now = Time.now
    events.select { |e| e.date >= now }.sort_by(&:date).first(n)
  end

  # The days of a game jam around +today+ (an event named a jam within three
  # days, and the two days after it), as a Range of Date, or nil.
  def jam(today = Date.today)
    event = events.find { |e| e.name.match?(/\bjam\b/i) && (e.date.to_date - today).abs <= 3 }
    event && (event.date.to_date..(event.date.to_date + 2))
  end

  # The team; empty while the site fails.
  def members = Remote.read('site members', []) { @repo.members }

  private

  def events = Remote.read('site events', []) { @repo.events }
end
