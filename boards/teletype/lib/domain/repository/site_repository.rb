# frozen_string_literal: true

require 'time'
require 'cgi'
require_relative 'http_json'

# The public teletypegames.org endpoints that are not the catalog:
# upcoming events and the team roster.
class SiteRepository
  include HttpJson

  API_URL = 'https://teletypegames.org/api/v1'

  Event  = Struct.new(:name, :date)
  Member = Struct.new(:nick, :real_nick, :motto)
  HowTo  = Struct.new(:title, :url, :description)

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

  # The tech how-tos of teletypegames.org/howtos: wiki pages, from the RSS
  # feed. A feed this plain needs no XML parser.
  def howtos
    cached(:howtos) do
      uri = URI("#{API_URL}/rss/howtos")
      xml = Net::HTTP.get(uri).force_encoding(Encoding::UTF_8)
      xml.scan(%r{<item>(.*?)</item>}m).map do |(item)|
        HowTo.new(tag(item, 'title'), tag(item, 'link'), tag(item, 'description'))
      end
    end
  rescue StandardError => e
    warn "SiteRepository howtos error: #{e}"
    []
  end

  private

  def tag(item, name)
    raw = item[%r{<#{name}>(.*?)</#{name}>}m, 1].to_s
    raw = raw.sub(/\A<!\[CDATA\[(.*)\]\]>\z/m, '\\1')
    CGI.unescapeHTML(raw).strip
  end
end
