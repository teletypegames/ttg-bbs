# frozen_string_literal: true

require 'time'
require 'rexml/document'
require 'rubbs/common/text'

# The model side's feed parser, pure functions with no I/O: the body of a
# feed, RSS 0.9x/2.0, RSS 1.0 (RDF) or Atom, as a ChannelModel of at most
# MAX_ITEMS items. Raises Unreadable when it is not a feed, or not XML
# REXML can read.
module FeedXml
  MAX_ITEMS = 60

  # A feed that could not be fetched or read.
  class Unreadable < StandardError
  end

  module_function

  # The ChannelModel of +feed+ (a FeedModel) from its XML +body+.
  def channel(feed, body)
    root = REXML::Document.new(body).root or raise Unreadable, 'not XML'
    parse(feed, root)
  rescue REXML::ParseException, RuntimeError => e
    raise Unreadable, "not XML: #{e.message.lines.first.to_s.strip[0, 80]}"
  end

  # The ChannelModel of the feed whose XML root element is +root+.
  def parse(feed, root)
    case root.name
    when 'rss' then rss(feed, child(root, 'channel') || raise(Unreadable, 'no channel'), nil)
    when 'RDF' then rss(feed, child(root, 'channel') || root, root)
    when 'feed' then atom(feed, root)
    else raise Unreadable, "not a feed: <#{root.name}>"
    end
  end

  # RSS 2.0 keeps its items in the channel, RSS 1.0 next to it.
  def rss(feed, channel, rdf)
    ChannelModel.new(
      feed:        feed,
      title:       channel_title(feed, text(child(channel, 'title'))),
      link:        link(text(child(channel, 'link'))),
      description: HtmlText.plain(text(child(channel, 'description'))),
      items:       children(rdf || channel, 'item').first(MAX_ITEMS).map { |item| rss_item(item) }
    )
  end

  def rss_item(item)
    body = text(child(item, 'encoded', prefix: 'content')) || text(child(item, 'description'))
    ItemModel.new(
      title:    title(text(child(item, 'title')), body),
      link:     link(text(child(item, 'link'))) || guid(item),
      date:     date(text(child(item, 'pubDate')) || text(child(item, 'date', prefix: 'dc'))),
      author:   HtmlText.plain(text(child(item, 'creator', prefix: 'dc')) || text(child(item, 'author'))),
      markdown: HtmlText.markdown(body)
    )
  end

  def atom(feed, root)
    ChannelModel.new(
      feed:        feed,
      title:       channel_title(feed, content(child(root, 'title'))),
      link:        atom_link(root),
      description: HtmlText.plain(content(child(root, 'subtitle'))),
      items:       children(root, 'entry').first(MAX_ITEMS).map { |entry| atom_item(entry) }
    )
  end

  def atom_item(entry)
    body = content(child(entry, 'content')) || content(child(entry, 'summary'))
    ItemModel.new(
      title:    title(content(child(entry, 'title')), body),
      link:     atom_link(entry),
      date:     date(text(child(entry, 'published')) || text(child(entry, 'updated'))),
      author:   HtmlText.plain(text(child(child(entry, 'author'), 'name'))),
      markdown: HtmlText.markdown(body)
    )
  end

  def channel_title(feed, raw) = HtmlText.plain(raw).then { |t| t.empty? ? feed.name : t }

  def title(raw, body)
    t = HtmlText.plain(raw)
    return t unless t.empty?

    HtmlText.plain(body).then { |b| b.empty? ? '(untitled)' : "#{b[0, 60]}…" }
  end

  def guid(item)
    g = link(text(child(item, 'guid')))
    g if g&.match?(%r{\Ahttps?://})
  end

  def atom_link(el)
    links = children(el, 'link')
    chosen = links.find { |l| [nil, 'alternate'].include?(l.attributes['rel']) } || links.first
    link(chosen&.attributes&.[]('href'))
  end

  # An address as shown under an item: one line, no control characters;
  # nil when there is none.
  def link(raw)
    address = Rubbs::Common::Text.clean(raw, keep_newlines: false).strip
    address.empty? ? nil : address
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
