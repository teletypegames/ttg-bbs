# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class GutenbergRepositoryTest < Minitest::Test
  include TempDir

  def setup
    super
    @gutenberg = GutenbergRepository.new(
      mirror:      'https://mirror.example/',
      catalog_url: 'https://mirror.example/pg_catalog.csv.gz'
    )
  end

  def answer(status, body = '') = Rubbs::Common::Web::HTTP::Response.new(status: status, body: body.b, headers: {})

  def with_http(result, &)
    asked = []
    get = lambda do |url, **options|
      asked << [url, options]
      raise result if result.is_a?(Exception)
      return result unless options[:to] && result.ok?

      options[:to].write(result.body)
      Rubbs::Common::Web::HTTP::Response.new(status: result.status, body: nil, headers: {})
    end
    Rubbs::Common::Web::HTTP.stub(:get, get) { capture_io(&) }
    asked
  end

  def test_fetches_a_text_with_the_cap
    text = nil
    asked = with_http(answer(200, 'Call me Ishmael.')) { text = @gutenberg.text(2701, max_bytes: 100) }

    assert_equal 'Call me Ishmael.', text
    url, options = asked.first
    assert_equal 'https://mirror.example/cache/epub/2701/pg2701.txt', url
    assert_equal 100, options[:max_bytes]
  end

  def test_a_failing_mirror_raises
    error = assert_raises(Rubbs::Common::Web::HTTP::Error) { with_http(answer(404)) { @gutenberg.text(1, max_bytes: 100) } }
    assert_equal 'GET https://mirror.example/cache/epub/1/pg1.txt: answered 404', error.message

    big = Rubbs::Common::Web::HTTP::TooLarge.new('GET https://mirror.example/x: the body is over 100 bytes')
    assert_raises(Rubbs::Common::Web::HTTP::TooLarge) { with_http(big) { @gutenberg.text(1, max_bytes: 100) } }
  end

  def test_streams_the_catalog_into_its_file
    file = path('pg_catalog.csv.gz')
    asked = with_http(answer(200, 'gz')) { @gutenberg.download_catalog(file) }

    assert_equal 'gz', File.read(file)
    assert_kind_of File, asked.first[1][:to]
    assert_raises(Rubbs::Common::Web::HTTP::Error) { with_http(answer(500)) { @gutenberg.download_catalog(path('other.gz')) } }
    refute_path_exists path('other.gz')
    refute_path_exists path('other.gz.part')
  end
end
