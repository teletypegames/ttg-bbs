# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'time'
require 'yaml'
require 'rexml/document'
require_relative 'html_text'

# The configured feeds and what they say: a feed is fetched over HTTP(S),
# read as RSS 0.9x/2.0, RSS 1.0 (RDF) or Atom, and its items kept for a few
# minutes. Every request names the reader in its User-Agent.
class Feeds
  USER_AGENT = 'Feedia/0.1 (Teletype Games telnet RSS reader; https://git.teletypegames.org/bbs/feedia)'
  TTL        = 600
  MAX_BYTES  = 4 * 1024 * 1024
  MAX_ITEMS  = 60
  REDIRECTS  = 4
  ACCEPT     = 'application/rss+xml, application/atom+xml, application/xml;q=0.9, */*;q=0.5'

  Feed    = Struct.new(:name, :url, :group, :lang, :about, keyword_init: true)
  Item    = Struct.new(:title, :link, :date, :author, :markdown, keyword_init: true)
  Channel = Struct.new(:feed, :title, :link, :description, :items, keyword_init: true)

  class Unreadable < StandardError
  end

  attr_reader :list

  def self.load(path)
    entries = YAML.safe_load_file(path) || []
    new(entries.filter_map do |e|
      next unless e.is_a?(Hash) && e['name'] && e['url'].to_s.match?(%r{\Ahttps?://}i)

      Feed.new(name: e['name'].to_s, url: e['url'].to_s, group: e['group'].to_s, lang: e['lang'].to_s,
               about: e['about'].to_s)
    end)
  end

  def initialize(list)
    @list  = list
    @cache = {}
    @mu    = Mutex.new
  end

  # The feed as a Channel; nil when it could not be fetched or read. With
  # +fresh+ the cache is skipped.
  def read(feed, fresh: false)
    hit = @mu.synchronize { @cache[feed.url] }
    return hit[1] if hit && !fresh && Time.now - hit[0] < TTL

    channel = parse(feed, fetch(feed.url))
    @mu.synchronize { @cache[feed.url] = [Time.now, channel] }
    channel
  rescue StandardError => e
    warn "Feed error (#{feed.url}): #{e.class}: #{e.message}"
    nil
  end

  private

  def fetch(url, hops = REDIRECTS)
    uri  = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.open_timeout = 10
    http.read_timeout = 15
    request = Net::HTTP::Get.new(uri.request_uri, 'User-Agent' => USER_AGENT, 'Accept' => ACCEPT)
    http.request(request) do |response|
      case response
      when Net::HTTPRedirection
        raise Unreadable, 'too many redirects' if hops.zero?

        return fetch(URI.join(url, response['location']).to_s, hops - 1)
      when Net::HTTPSuccess
        body = +''
        response.read_body do |chunk|
          body << chunk
          raise Unreadable, 'the feed is too big' if body.bytesize > MAX_BYTES
        end
        return body
      else
        raise Unreadable, "HTTP #{response.code}"
      end
    end
  end

  def parse(feed, body)
    root = REXML::Document.new(body).root or raise Unreadable, 'not XML'
    case root.name
    when 'rss' then rss(feed, child(root, 'channel') || raise(Unreadable, 'no channel'), nil)
    when 'RDF' then rss(feed, child(root, 'channel') || root, root)
    when 'feed' then atom(feed, root)
    else raise Unreadable, "not a feed: <#{root.name}>"
    end
  end

  # RSS 2.0 keeps its items in the channel, RSS 1.0 next to it.
  def rss(feed, channel, rdf)
    items = children(rdf || channel, 'item').first(MAX_ITEMS).map do |item|
      body = text(child(item, 'encoded', prefix: 'content')) || text(child(item, 'description'))
      Item.new(title: title(text(child(item, 'title')), body), link: text(child(item, 'link')) || guid(item),
               date: date(text(child(item, 'pubDate')) || text(child(item, 'date', prefix: 'dc'))),
               author: HtmlText.plain(text(child(item, 'creator', prefix: 'dc')) || text(child(item, 'author'))),
               markdown: HtmlText.markdown(body))
    end
    Channel.new(feed: feed, title: HtmlText.plain(text(child(channel, 'title'))).then { |t| t.empty? ? feed.name : t },
                link: text(child(channel, 'link')), description: HtmlText.plain(text(child(channel, 'description'))),
                items: items)
  end

  def atom(feed, root)
    items = children(root, 'entry').first(MAX_ITEMS).map do |entry|
      body = content(child(entry, 'content')) || content(child(entry, 'summary'))
      Item.new(title: title(content(child(entry, 'title')), body), link: atom_link(entry),
               date: date(text(child(entry, 'published')) || text(child(entry, 'updated'))),
               author: HtmlText.plain(text(child(child(entry, 'author'), 'name'))),
               markdown: HtmlText.markdown(body))
    end
    Channel.new(feed: feed, title: HtmlText.plain(content(child(root, 'title'))).then { |t| t.empty? ? feed.name : t },
                link: atom_link(root), description: HtmlText.plain(content(child(root, 'subtitle'))), items: items)
  end

  def title(raw, body)
    t = HtmlText.plain(raw)
    return t unless t.empty?

    HtmlText.plain(body).then { |b| b.empty? ? '(untitled)' : "#{b[0, 60]}…" }
  end

  def guid(item)
    g = text(child(item, 'guid'))
    g if g&.match?(%r{\Ahttps?://})
  end

  def atom_link(el)
    links = children(el, 'link')
    link  = links.find { |l| [nil, 'alternate'].include?(l.attributes['rel']) } || links.first
    link&.attributes&.[]('href')
  end

  # Atom text constructs: text, escaped html, or inline xhtml.
  def content(el)
    return nil unless el
    return el.children.join if el.attributes['type'] == 'xhtml'

    text(el)
  end

  def date(raw)
    raw = raw.to_s.strip
    return nil if raw.empty?

    %i[rfc2822 iso8601 parse].each do |format|
      return Time.public_send(format, raw)
    rescue ArgumentError
      next
    end
    nil
  end

  # The child elements of that name; with no prefix, only the unprefixed
  # ones, so an atom:link in an RSS channel is not taken for its link.
  def children(el, name, prefix: '')
    return [] unless el

    el.elements.select { |e| e.name == name && e.prefix.to_s == prefix }
  end

  def child(el, name, prefix: '') = children(el, name, prefix: prefix).first

  def text(el)
    return nil unless el

    value = el.texts.map(&:value).join.strip
    value.empty? ? nil : value
  end
end
