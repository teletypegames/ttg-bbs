# frozen_string_literal: true

require 'test_helper'

class FeedRepositoryTest < Minitest::Test
  FEED = FeedModel.new(name: 'Test', url: 'https://feed.example/rss', group: '', lang: '', about: '')
  BODY = '<rss><channel><title>T</title><item><title>One</title></item></channel></rss>'

  def test_a_feed_is_fetched_once_and_kept
    http = FakeHTTP.new(body: BODY)
    repo = FeedRepository.new(http: http)
    assert_equal 'One', repo.read(FEED).items.first.title
    repo.read(FEED)
    assert_equal 1, http.calls
  end

  def test_callers_at_once_share_one_fetch
    http = FakeHTTP.new(body: BODY, delay: 0.2)
    repo = FeedRepository.new(http: http)
    channels = Array.new(8) { Thread.new { repo.read(FEED) } }.map(&:value)
    assert_equal 1, http.calls
    assert(channels.all? { |c| c&.title == 'T' })
  end

  def test_fresh_fetches_again
    http = FakeHTTP.new(body: BODY)
    repo = FeedRepository.new(http: http)
    repo.read(FEED)
    repo.read(FEED, fresh: true)
    assert_equal 2, http.calls
  end

  def test_a_failure_goes_up
    down = Rubbs::Common::Web::HTTP::Error.new('GET https://feed.example/rss: down')
    assert_raises(Rubbs::Common::Web::HTTP::Error) { FeedRepository.new(http: FakeHTTP.new(error: down)).read(FEED) }
    assert_raises(Rubbs::Common::Web::HTTP::Error) { FeedRepository.new(http: FakeHTTP.new(body: 'nope', status: 404)).read(FEED) }
    assert_raises(FeedXml::Unreadable) { FeedRepository.new(http: FakeHTTP.new(body: '<html/>')).read(FEED) }
    assert_raises(FeedXml::Unreadable) { FeedRepository.new(http: FakeHTTP.new(body: '<rss><channel>')).read(FEED) }
  end

  def test_the_service_logs_a_failure_once_and_shows_none
    big  = Rubbs::Common::Web::HTTP::TooLarge.new('GET https://feed.example/rss: the body is over 1048576 bytes')
    list = Struct.new(:all).new([FEED])
    _, err = capture_io { assert_nil FeedService.new(list, FeedRepository.new(http: FakeHTTP.new(error: big))).read(FEED) }
    assert_equal 1, err.lines.size
    assert_match(/: feed: Test: Rubbs::Common::Web::HTTP::TooLarge: /, err)
  end
end
