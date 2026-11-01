# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class GutenbergRepositoryTest < Minitest::Test
  include TempDir

  def setup
    super
    @gutenberg = GutenbergRepository.new(mirror: 'https://mirror.example/', user_agent: 'Test/1',
                                         catalog_url: 'https://mirror.example/pg_catalog.csv.gz')
  end

  def answer(status, body = '') = BBS::HTTP::Response.new(status: status, body: body.b, headers: {})

  def with_http(result, &)
    asked = []
    get = lambda do |url, **options|
      asked << [url, options]
      raise result if result.is_a?(Exception)

      result
    end
    BBS::HTTP.stub(:get, get) { capture_io(&) }
    asked
  end

  def test_fetches_a_text_with_the_board_user_agent_and_the_cap
    text = nil
    asked = with_http(answer(200, 'Call me Ishmael.')) { text = @gutenberg.text(2701, max_bytes: 100) }

    assert_equal 'Call me Ishmael.', text
    url, options = asked.first
    assert_equal 'https://mirror.example/cache/epub/2701/pg2701.txt', url
    assert_equal 100, options[:max_bytes]
    assert_equal 'Test/1', options[:user_agent]
  end

  def test_a_text_over_the_cap_is_too_big
    text = nil
    with_http(BBS::HTTP::Error.new('GET https://mirror.example/x: the body is over 100 bytes')) do
      text = @gutenberg.text(1, max_bytes: 100)
    end

    assert_equal :too_big, text
  end

  def test_a_failing_mirror_gives_nil
    text = :none
    with_http(answer(404)) { text = @gutenberg.text(1, max_bytes: 100) }
    assert_nil text

    with_http(BBS::HTTP::Error.new('GET https://mirror.example/x: the deadline passed')) do
      text = @gutenberg.text(1, max_bytes: 100)
    end
    assert_nil text
  end

  def test_saves_the_catalog_file
    file = path('pg_catalog.csv.gz')
    ok = nil
    with_http(answer(200, 'gz')) { ok = @gutenberg.download_catalog(file) }

    assert ok
    assert_equal 'gz', File.read(file)
    with_http(answer(500)) { ok = @gutenberg.download_catalog(path('other.gz')) }
    refute ok
    refute_path_exists path('other.gz')
  end
end
