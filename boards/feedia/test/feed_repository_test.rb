# frozen_string_literal: true

require 'test_helper'

class FeedRepositoryTest < Minitest::Test
  FEED = FeedModel.new(name: 'Test', url: 'https://feed.example/rss', group: '', lang: '', about: '')
  BODY = '<rss><channel><title>T</title><item><title>One</title></item></channel></rss>'

  def setup = $stderr = StringIO.new

  def teardown = $stderr = STDERR

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

  def test_a_failure_is_nil
    down = BBS::HTTP::Error.new('GET https://feed.example/rss: down')
    assert_nil FeedRepository.new(http: FakeHTTP.new(error: down)).read(FEED)
    assert_nil FeedRepository.new(http: FakeHTTP.new(body: 'nope', status: 404)).read(FEED)
    assert_nil FeedRepository.new(http: FakeHTTP.new(body: '<html/>')).read(FEED)
  end
end
