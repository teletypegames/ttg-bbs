# frozen_string_literal: true

require 'test_helper'

class WikipediaClientTest < Minitest::Test
  def client(pace: BBS::RateLimit.new(limit: 5, per: 1)) = WikipediaClient.new(user_agent: 'Test/1', pace: pace)

  def test_a_request_names_the_board_and_asks_for_json
    wiki = FakeWikipedia.new { { 'ok' => true } }
    assert_equal('{"ok":true}', wiki.serve { client.get('hu', action: 'query') })
    uri, options = wiki.requests.first
    assert_equal ['hu.wikipedia.org', 'Test/1'], [uri.host, options[:user_agent]]
    assert_includes uri.query, 'formatversion=2'
  end

  def test_an_error_status_raises
    wiki = FakeWikipedia.new(status: 429) { {} }
    error = assert_raises(WikipediaClient::Error) { wiki.serve { client.get('en', action: 'query') } }
    assert_equal 'Wikipedia answered 429', error.message
  end

  def test_a_request_that_would_wait_too_long_is_not_sent
    wiki = FakeWikipedia.new { {} }
    pace = BBS::RateLimit.new(limit: 1, per: WikipediaClient::MAX_WAIT + 5)
    c    = client(pace: pace)
    wiki.serve { c.get('en', action: 'query') }
    assert_raises(WikipediaClient::Error) { wiki.serve { c.get('en', action: 'query') } }
    assert_equal 1, wiki.requests.size
  end

  def test_a_request_waits_for_its_turn
    wiki = FakeWikipedia.new { {} }
    c    = client(pace: BBS::RateLimit.new(limit: 1, per: 0.2))
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    wiki.serve { 2.times { c.get('en', action: 'query') } }
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :>=, 0.15
  end
end
