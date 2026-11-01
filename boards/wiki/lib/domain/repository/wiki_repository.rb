# frozen_string_literal: true

require 'json'
require 'uri'

# The Grav wiki's JSON API (/custom/sitemap.json, /custom/page.json), over
# BBS::HTTP on the Docker network, with the page bodies in a bounded
# BBS::Cache, so browsing the list does not fetch a page again on every
# selection change. Every text that comes from the wiki is cleaned of
# control characters here. A network or HTTP error is raised: the index
# loader retries, and the wiki service words it for the caller.
class WikiRepository
  PAGE_TTL   = 300 # seconds
  PAGE_LIMIT = 200
  PAGE_BYTES = 8 * 1024 * 1024

  # The wiki did not answer with a page. Its message names the path and the
  # status only, never the query: that carries the supervisor token.
  class Error < StandardError; end

  attr_reader :base_url

  # +token+ is sent as ?token= on private page requests only: the wiki serves
  # private page bodies when it matches its own SUPERVISOR_PASSWORD.
  # +user_agent+ names the board in every request.
  def initialize(base_url, user_agent:, token: nil)
    @base_url   = base_url.chomp('/')
    @user_agent = user_agent
    @token      = token.to_s
    @pages      = BBS::Cache.new(ttl: PAGE_TTL, max_entries: PAGE_LIMIT, max_bytes: PAGE_BYTES)
  end

  # Every routable page as a PageModel, in the wiki's order, each with its
  # own private flag.
  def sitemap
    (get_json('/custom/sitemap.json')['pages'] || []).map { |entry| PageModel.from_json(entry) }
  end

  # The /custom/page.json answer for +route+ (cached for PAGE_TTL): the page's
  # title and markdown, or its error ('forbidden', 'not_found'). Only a
  # +private+ page is asked for with the token.
  def page(route, private: false)
    params = { route: route }
    params[:token] = @token if private && !@token.empty?
    data = parse_json(@pages.fetch(route) { get('/custom/page.json', **params) })
    data.slice('title', 'markdown', 'error').transform_values { |text| BBS::Text.clean(text.to_s) }
  end

  def clear_cache = @pages.clear

  private

  def get_json(path, **params) = parse_json(get(path, **params))

  # The body of +path+ as UTF-8 text; the wiki is on the Docker network, so
  # not on the public internet.
  def get(path, **params)
    uri = URI("#{@base_url}#{path}")
    uri.query = URI.encode_www_form(params) unless params.empty?
    response = BBS::HTTP.get(uri.to_s, user_agent: @user_agent, public_only: false)
    raise Error, "HTTP #{response.status} for #{path}" unless response.ok?
    BBS::Text.utf8(response.body)
  rescue BBS::HTTP::Error => e
    raise Error, "#{path}: #{e.message}"
  end

  # Grav can prepend PHP deprecation notices to the body on a cold cache;
  # fall back to parsing from the first brace.
  def parse_json(body)
    JSON.parse(body)
  rescue JSON::ParserError
    start = body.index('{')
    raise unless start
    JSON.parse(body[start..])
  end
end
