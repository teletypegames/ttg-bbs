# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require_relative '../model/wiki_page_model'

# Reads the Grav wiki through its JSON endpoints (/custom/pages.json and
# /custom/page.json). The BBS is public, so login-only pages are left out.
class WikiRepository
  BASE_URL = 'https://wiki.teletypegames.org'

  def list(tag)
    data = get('/custom/pages.json', tag: tag)
    (data['pages'] || []).reject { |p| p['private'] }.map do |p|
      WikiPageModel.new(
        id:          p['id'],
        path:        p['path'],
        title:       p['title'],
        description: p['description'],
        created_at:  p['createdAt'],
        locale:      p['locale']
      )
    end
  rescue => e
    warn "WikiRepository list error: #{e}"
    []
  end

  def content(path)
    get('/custom/page.json', route: "/#{path}")['markdown'] || ''
  rescue => e
    warn "WikiRepository content error: #{e}"
    ''
  end

  def page_url(locale, path)
    prefix = locale == 'hu' ? '/hu' : ''
    "#{BASE_URL}#{prefix}/#{path}"
  end

  private

  def get(path, params)
    uri  = URI("#{BASE_URL}#{path}")
    uri.query = URI.encode_www_form(params)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.open_timeout = 12
    http.read_timeout = 12
    JSON.parse(http.get(uri.request_uri).body)
  end
end
