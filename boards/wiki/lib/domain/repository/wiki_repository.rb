# frozen_string_literal: true

require 'json'
require 'uri'

# The Grav wiki's JSON API (/custom/sitemap.json, /custom/page.json), over
# BBS::HTTP on the Docker network, with the page bodies in a bounded
# BBS::Cache, so browsing the list does not fetch a page again on every
# selection change. Every text that comes from the wiki is cleaned of
# control characters here. A network or HTTP error, or an answer that is not
# JSON, is raised as WikiRepository::Error: the index loader retries, and the
# wiki service words it for the caller.
class WikiRepository
  PAGE_TTL   = 300 # seconds
  PAGE_LIMIT = 200
  PAGE_BYTES = 8 * 1024 * 1024

  # The wiki did not answer with a page. Its message names the path and the
  # status only.
  class Error < StandardError; end

  attr_reader :base_url

  # +token+ is sent as the X-Wiki-Token header on private page requests only
  # (a header stays out of the wiki's access log): the wiki serves
  # private page bodies when it matches its own SUPERVISOR_PASSWORD.
  def initialize(base_url, token: nil)
    @base_url = base_url.chomp('/')
    @token    = token.to_s
    @pages    = BBS::Cache.new(ttl: PAGE_TTL, max_entries: PAGE_LIMIT, max_bytes: PAGE_BYTES)
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
    headers = private && !@token.empty? ? { 'X-Wiki-Token' => @token } : {}
    data = parse_json(@pages.fetch(route) { get('/custom/page.json', headers, route: route) })
    data.slice('title', 'markdown', 'error').transform_values { |text| BBS::Text.clean(text.to_s) }
  end

  def clear_cache = @pages.clear

  private

  def get_json(path, **params) = parse_json(get(path, {}, **params))

  # The body of +path+ as UTF-8 text; the wiki is on the Docker network, so
  # not on the public internet.
  def get(path, headers, **params)
    uri = URI("#{@base_url}#{path}")
    uri.query = URI.encode_www_form(params) unless params.empty?
    options = { public_only: false }
    options[:headers] = headers unless headers.empty?
    response = BBS::HTTP.get(uri.to_s, **options)
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
    start = body.index('{') or raise Error, 'the answer is not JSON'
    begin
      JSON.parse(body[start..])
    rescue JSON::ParserError
      raise Error, 'the answer is not JSON'
    end
  end
end
