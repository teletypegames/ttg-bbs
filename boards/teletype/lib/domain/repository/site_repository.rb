# frozen_string_literal: true

require 'time'
require_relative 'http_json'

# The public teletypegames.org endpoints that are not the catalog:
# the upcoming events and the team roster, kept five minutes.
class SiteRepository
  API_URL = 'https://teletypegames.org/api/v1'
  TTL     = 300

  Event  = Struct.new(:name, :date)
  Member = Struct.new(:nick, :real_nick, :motto)

  def initialize
    @cache = HttpJson::Cache.new(ttl: TTL)
  end

  # The events of the site. Raises BBS::HTTP::Error when the site fails.
  def events = @cache.fetch(:events) { HttpJson.get("#{API_URL}/events").filter_map { |e| event(e) } }

  # The team. Raises BBS::HTTP::Error when the site fails.
  def members
    @cache.fetch(:members) do
      HttpJson.get("#{API_URL}/members").map { |m| Member.new(m['nick'].to_s, m['realNick'].to_s, m['motto'].to_s) }
    end
  end

  private

  def event(entry)
    Event.new(entry['name'].to_s, Time.parse(entry['date'].to_s))
  rescue StandardError
    nil
  end
end
