# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require_relative '../model/wiki_page'

class WikiClient
  BASE_URL = 'https://wiki.teletype.hu'

  def initialize(token: nil)
    @token = token
  end

  def list(tag)
    query = <<~GQL
      { pages { list(orderBy: CREATED, orderByDirection: DESC, tags: ["#{tag}"]) {
        id path title description createdAt locale
      }}}
    GQL
    (graphql(query).dig('data', 'pages', 'list') || []).map do |p|
      WikiPage.new(
        id:          p['id'],
        path:        p['path'],
        title:       p['title'],
        description: p['description'],
        created_at:  p['createdAt'],
        locale:      p['locale']
      )
    end
  rescue => e
    warn "Wiki list error: #{e}"
    []
  end

  def content(page_id)
    query = "{ pages { single(id: #{page_id}) { content } } }"
    graphql(query).dig('data', 'pages', 'single', 'content') || ''
  rescue => e
    warn "Wiki content error: #{e}"
    ''
  end

  def page_url(locale, path)
    "#{BASE_URL}/#{locale}/#{path}"
  end

  private

  def graphql(query)
    uri  = URI("#{BASE_URL}/graphql")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl       = uri.scheme == 'https'
    http.open_timeout  = 12
    http.read_timeout  = 12

    req = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    req['Authorization'] = "Bearer #{@token}" if @token
    req.body = JSON.generate(query: query)

    JSON.parse(http.request(req).body)
  end
end
