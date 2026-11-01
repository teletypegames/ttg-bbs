# frozen_string_literal: true

require 'time'
require_relative 'http_json'

# The public teletypegames.org endpoints that are not the catalog:
# upcoming events, the team roster and the blog (written on
# TTG Blog BBS, served by the site's API).
class SiteRepository
  include HttpJson

  API_URL = 'https://teletypegames.org/api/v1'

  Event  = Struct.new(:name, :date)
  Member = Struct.new(:nick, :real_nick, :motto)
  Post   = Struct.new(:title, :summary, :slug, :author, :created_at) do
    def url = "https://teletypegames.org/blog/#{slug}"
  end

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

  def blog_posts
    cached(:blog_posts) do
      get_json("#{API_URL}/blog/posts").fetch('posts', []).filter_map do |p|
        Post.new(p['title'].to_s, p['summary'].to_s, p['slug'].to_s, p['author'], Time.parse(p['created_at'].to_s))
      rescue StandardError
        nil
      end
    end
  rescue StandardError => e
    warn "SiteRepository blog error: #{e}"
    []
  end
end
