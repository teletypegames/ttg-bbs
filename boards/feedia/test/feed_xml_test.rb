# frozen_string_literal: true

require 'test_helper'

class FeedXmlTest < Minitest::Test
  FEED = FeedModel.new(name: 'Test', url: 'https://feed.example/rss', group: '', lang: 'en', about: '')

  RSS = <<~XML
    <?xml version="1.0"?>
    <rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
      <channel>
        <title>The &lt;b&gt;Paper&lt;/b&gt;</title>
        <link>https://feed.example/</link>
        <description>News</description>
        <item>
          <title>First</title>
          <link>https://feed.example/1&#x9b;2J&#x202e;</link>
          <pubDate>Sat, 31 Oct 2026 10:00:00 +0000</pubDate>
          <dc:creator>Ada</dc:creator>
          <description>&lt;p&gt;Hello&lt;/p&gt;</description>
        </item>
        <item>
          <guid>https://feed.example/2</guid>
          <description>No title here, only a body that is long enough</description>
        </item>
      </channel>
    </rss>
  XML

  ATOM = <<~XML
    <?xml version="1.0" encoding="utf-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>Atom Paper</title>
      <link rel="self" href="https://atom.example/feed"/>
      <link href="https://atom.example/"/>
      <entry>
        <title type="html">One &amp;amp; two</title>
        <link rel="alternate" href="https://atom.example/1&#x9d;0;pwned"/>
        <updated>2026-10-31T10:00:00Z</updated>
        <author><name>Grace</name></author>
        <content type="html">&lt;p&gt;Body&lt;/p&gt;</content>
      </entry>
    </feed>
  XML

  def test_rss
    channel = FeedXml.channel(FEED, RSS)
    assert_equal 'The Paper', channel.title
    first, second = channel.items
    assert_equal ['First', 'https://feed.example/12J', 'Ada', 'Hello'], [first.title, first.link, first.author, first.markdown]
    assert_equal Time.utc(2026, 10, 31, 10), first.date
    assert_equal 'https://feed.example/2', second.link
    assert_match(/\ANo title here, only a body that is long enough/, second.title)
  end

  def test_atom
    channel = FeedXml.channel(FEED, ATOM)
    item = channel.items.first
    assert_equal ['Atom Paper', 'https://atom.example/'], [channel.title, channel.link]
    assert_equal ['One & two', 'https://atom.example/10;pwned', 'Grace', 'Body'],
                 [item.title, item.link, item.author, item.markdown]
  end

  def test_not_a_feed
    assert_raises(FeedXml::Unreadable) { FeedXml.channel(FEED, '<html><body>hi</body></html>') }
  end

  def test_at_most_max_items
    items = '<item><title>x</title></item>' * (FeedXml::MAX_ITEMS + 5)
    assert_equal FeedXml::MAX_ITEMS, FeedXml.channel(FEED, "<rss><channel>#{items}</channel></rss>").items.size
  end
end
