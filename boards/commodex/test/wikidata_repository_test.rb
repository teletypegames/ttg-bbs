# frozen_string_literal: true

require 'test_helper'

class WikidataRepositoryTest < Minitest::Test
  def item(qid) = { 'type' => 'uri', 'value' => "http://www.wikidata.org/entity/#{qid}" }

  def bindings(query)
    if query.include?('?itemLabel ?article')
      [{
        'item'      => item('Q1'),
        'itemLabel' => { 'value' => "Zork\e[2J" },
        'article'   => { 'value' => 'https://en.wikipedia.org/wiki/Zork_I' }
      }]
    elsif query.include?('?date')
      [{ 'item' => item('Q1'), 'date' => { 'value' => '1983-01-01' }, 'platform' => item('Q99775') },
       { 'item' => item('Q1'), 'date' => { 'value' => '1980-01-01' } }]
    else
      [{ 'item' => item('Q1'), 'v' => item('Q5'), 'vLabel' => { 'value' => "single-player video game\e" } }]
    end
  end

  def post(_url, body:, **options)
    @posts << options
    query = URI.decode_www_form(body).to_h['query']
    BBS::HTTP::Response.new(status: 200, body: JSON.generate('results' => { 'bindings' => bindings(query) }), headers: {})
  end

  def test_the_records_are_merged_and_cleaned
    @posts = []
    records = BBS::HTTP.stub(:post, ->(url, **options) { post(url, **options) }) { WikidataRepository.new(pause: 0).records }
    zork = records.first
    assert_equal ['Zork[2J', 'Zork I', 1983, ['single-player']], [zork['t'], zork['w'], zork['y'], zork['mod']]
    assert_equal WikidataRepository::USER_AGENT, @posts.first[:user_agent]
  end

  def test_a_failed_query_raises
    failing = ->(*, **) { raise BBS::HTTP::Error, 'timeout' }
    assert_raises(BBS::HTTP::Error) { BBS::HTTP.stub(:post, failing) { WikidataRepository.new(pause: 0).records } }
    status = ->(*, **) { BBS::HTTP::Response.new(status: 502, body: '', headers: {}) }
    error = assert_raises(WikidataRepository::Error) { BBS::HTTP.stub(:post, status) { WikidataRepository.new(pause: 0).records } }
    assert_equal 'Wikidata answered 502', error.message
  end
end
