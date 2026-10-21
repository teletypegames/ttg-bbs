# frozen_string_literal: true

require 'time'
require_relative 'http_json'

# The public teletypegames.org endpoints that are not the catalog:
# upcoming events and the team roster.
class SiteRepository
  include HttpJson

  API_URL = 'https://teletypegames.org/api/v1'

  Event  = Struct.new(:name, :date)
  Member = Struct.new(:nick, :real_nick, :motto)

  def events
    cached(:events) do
      get_json("#{API_URL}/events").filter_map do |e|
        Event.new(e['name'].to_s, Time.parse(e['date'].to_s))
      rescue StandardError
        nil
      end
    end
  rescue StandardError => e
    warn "SiteRepository events error: #{e}"
    []
  end

  def members
    cached(:members) do
      get_json("#{API_URL}/members").map do |m|
        Member.new(m['nick'].to_s, m['realNick'].to_s, m['motto'].to_s)
      end
    end
  rescue StandardError => e
    warn "SiteRepository members error: #{e}"
    []
  end
end
