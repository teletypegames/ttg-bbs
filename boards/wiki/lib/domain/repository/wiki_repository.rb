# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

# The Grav wiki's JSON API (/custom/sitemap.json, /custom/page.json), with
# an in-memory page cache, so browsing the list does not fetch a page again
# on every selection change. A network or HTTP error is raised: the index
# loader retries, and the wiki service words it for the caller.
class WikiRepository
  PAGE_TTL = 300 # seconds

  # The wiki did not answer with a page. Its message names the path and the
  # status only, never the query: that carries the supervisor token.
  class Error < StandardError; end

  attr_reader :base_url

  # +token+ is sent as ?token= on private page requests only: the wiki serves
  # private page bodies when it matches its own SUPERVISOR_PASSWORD.
  def initialize(base_url, token: nil)
    @base_url = base_url.chomp('/')
    @token    = token.to_s
    @cache    = {}
    @mutex    = Mutex.new
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
    @mutex.synchronize do
      hit = @cache[route]
      return hit[:data] if hit && Time.now - hit[:at] < PAGE_TTL
    end

    params = { route: route }
    params[:token] = @token if private && !@token.empty?
    data = get_json('/custom/page.json', **params)
    @mutex.synchronize { @cache[route] = { data: data, at: Time.now } }
    data
  end

  def clear_cache
    @mutex.synchronize { @cache.clear }
  end

  private

  def get_json(path, **params)
    uri = URI("#{@base_url}#{path}")
    uri.query = URI.encode_www_form(params) unless params.empty?
    res = Net::HTTP.start(uri.host, uri.port,
                          use_ssl: uri.scheme == 'https',
                          open_timeout: 5, read_timeout: 15) do |http|
      http.get(uri.request_uri)
    end
    raise Error, "HTTP #{res.code} for #{path}" unless res.is_a?(Net::HTTPSuccess)

    parse_json(res.body)
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
