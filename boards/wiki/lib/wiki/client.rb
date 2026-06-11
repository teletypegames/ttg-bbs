# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module Wiki
  # Thin JSON client for the Grav wiki's /api endpoints, with an in-memory
  # per-route page cache so browsing the list doesn't re-fetch on every
  # selection change.
  class Client
    PAGE_TTL = 300 # seconds

    attr_reader :base_url

    # token: sent as ?token= on page requests — the wiki only serves private
    # page bodies when it matches its own SUPERVISOR_PASSWORD.
    def initialize(base_url:, token: nil)
      @base_url = base_url.chomp('/')
      @token    = token.to_s
      @cache    = {}
      @pages    = []
      @mutex    = Mutex.new
    end

    # The page index, loaded once at server boot (see wiki.rb) and shared by
    # every session. Refresh with #refresh_index!.
    attr_reader :pages

    def refresh_index!
      @pages = sitemap
    end

    # All wiki pages as a flat, route-sorted list (children follow their
    # parents). Each entry:
    # { route:, title:, depth:, updated_at:, tags:, private: }.
    # A page is private if it carries the flag itself or sits under a private
    # ancestor. Raises on network/HTTP errors — Flow's `fetch` step reports
    # those.
    def sitemap
      data  = get_json('/api/sitemap.json')
      pages = (data['pages'] || []).map do |p|
        route = p['route'].to_s
        {
          route:      route,
          title:      p['title'].to_s,
          depth:      [route.count('/'), 1].max,
          updated_at: p['updatedAt'].to_s[0, 10],
          tags:       p['tags'] || [],
          private:    p['private'] == true
        }
      end
      private_roots = pages.select { |p| p[:private] }.map { |p| p[:route] }
      pages.each do |p|
        p[:private] ||= private_roots.any? { |r| p[:route].start_with?("#{r}/") }
      end
      pages.sort_by { |p| p[:route] }
    end

    # Markdown body for one route, prefixed with the page title as an H1
    # (cached for PAGE_TTL). Fetch problems come back as renderable markdown
    # so the detail pane can show them as-is.
    def page_markdown(route)
      @mutex.synchronize do
        hit = @cache[route]
        return hit[:md] if hit && Time.now - hit[:at] < PAGE_TTL
      end

      params = { route: route }
      params[:token] = @token unless @token.empty?
      data = get_json('/api/page.json', **params)
      md   = case data['error']
             when 'forbidden'
               "# Forbidden\n\nThe wiki refused the supervisor token for " \
               "`#{route}` — check that SUPERVISOR_PASSWORD matches on both " \
               "services."
             when nil
               "# #{data['title']}\n\n#{data['markdown']}"
             else
               "# Not found\n\nNo wiki page at `#{route}`."
             end
      @mutex.synchronize { @cache[route] = { md: md, at: Time.now } }
      md
    rescue StandardError => e
      "# Error\n\nCould not fetch `#{route}`:\n\n`#{e.class}: #{e.message}`"
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
      raise "HTTP #{res.code} for #{uri}" unless res.is_a?(Net::HTTPSuccess)

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
end
