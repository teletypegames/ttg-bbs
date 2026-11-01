# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class SixteenColorsRepositoryTest < Minitest::Test
  def repo(ttl: 3600, max_bytes: 1024)
    SixteenColorsRepository.new(api_url: 'https://api.test', site_url: 'https://site.test', user_agent: 'test',
                                ttl: ttl, max_bytes: max_bytes)
  end

  def ok(body) = BBS::HTTP::Response.new(status: 200, body: body.b, headers: {})

  # Runs the block with BBS::HTTP.get answered by +answer+ (url, options);
  # yields the calls made, [[url, options], …].
  def answering(answer)
    calls = []
    get = lambda do |url, **opts|
      calls << [url, opts]
      answer.call(url, opts)
    end
    BBS::HTTP.stub(:get, get) { yield calls }
  end

  def body(text) = ->(_url, _opts) { ok(text) }

  def test_years_newest_first_without_empty_ones
    answering(body('{"1996":{"packs":3},"1997":{"packs":0},"2001":{"packs":1}}')) do |calls|
      assert_equal [2001, 1996], repo.years.map(&:year)
      assert_equal 'test', calls.first[1][:user_agent]
    end
  end

  def test_a_dead_api_gives_nil_then_the_last_listing
    r = repo(ttl: 0)
    answering(->(*) { raise BBS::HTTP::Error, 'GET https://api.test/v1/year: refused' }) do
      capture_io { assert_nil r.years }
    end
    answering(body('{"1996":{"packs":3}}')) { assert_equal [1996], r.years.map(&:year) }
    answering(body('not json')) do
      capture_io { assert_equal [1996], r.years.map(&:year) }
    end
  end

  def test_packs_read_every_page_and_clean_names
    pages = {
      '1' => '{"page":{"pages":2},"results":[{"name":"acid-96\u001b[2J","year":1996,"groups":["ACiD"]}]}',
      '2' => '{"page":{"pages":2},"results":[{"name":"ice-96","year":1996,"groups":[]}]}'
    }
    answering(->(url, _) { ok(pages.fetch(url[/page=(\d)/, 1])) }) do
      assert_equal ['acid-96[2J', 'ice-96'], repo.packs(1996).map(&:name)
    end
  end

  def test_files_keep_the_sauce_clean
    sauce = { 'Title' => "T\u001b]52;c;x\u0007", 'Datatype' => 1, 'Filetype' => 1, 'Tinfo1' => 80 }
    listing = { results: [{ files: { "a\u0007.ans" => { 'artists' => ["x\u009b"], 'sauce' => sauce } } }] }
    answering(body(JSON.generate(listing))) do
      file = repo.files('pack').first
      assert_equal 'a.ans', file.name
      assert_equal 'T]52;c;x', file.title
      assert_equal ['x'], file.artists
      assert_equal 80, file.width
    end
  end

  def test_raw_is_fetched_once_for_callers_at_once
    r = repo
    slow = lambda do |_url, _opts|
      sleep 0.1
      ok('ART')
    end
    answering(slow) do |calls|
      pieces = Array.new(4) { Thread.new { r.raw('pack', 'a b.ans') } }.map(&:value)
      assert_equal ['ART'] * 4, pieces
      assert_equal 1, calls.size
      assert_equal 'https://site.test/pack/pack/raw/a%20b.ans', calls.first[0]
      assert_equal 1024, calls.first[1][:max_bytes]
    end
  end

  def test_a_file_over_the_cap_is_too_big_and_a_missing_one_nil
    r = repo
    answer = lambda do |url, opts|
      raise BBS::HTTP::Error, "GET #{url}: the body is over #{opts[:max_bytes]} bytes" if url.end_with?('big.ans')

      BBS::HTTP::Response.new(status: 404, body: ''.b, headers: {})
    end
    answering(answer) do
      assert_equal :too_big, r.raw('pack', 'big.ans')
      capture_io { assert_nil r.raw('pack', 'gone.ans') }
    end
  end
end
