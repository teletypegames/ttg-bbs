# frozen_string_literal: true

require 'test_helper'

class WikidataRepositoryTest < Minitest::Test
  def item(qid) = { 'type' => 'uri', 'value' => "http://www.wikidata.org/entity/#{qid}" }

  def prop(name) = { 'value' => "http://www.wikidata.org/prop/direct/#{name}" }

  # The rows of each kind of query.
  def bindings(query)
    case query
    when /wdt:P279\* wd:Q8076/
      [{ 'item' => item('Q1'), 'type' => item('Q10929058') }, { 'item' => item('Q2'), 'sup' => item('Q8076') },
       { 'item' => item('Q3'), 'type' => item('Q7889') }]
    when /wdt:P279\* wd:/ then [{ 'item' => item('Q4') }, { 'item' => item('Q5'), 'sup' => item('Q4') }]
    when /\?itemLabel/ then names
    when /UNION/ then [{ 'item' => item('Q1'), 'p' => prop('P176'), 'vLabel' => { 'value' => "Atari\e" } },
                       { 'item' => item('Q1'), 'p' => prop('P156'), 'v' => item('Q5') },
                       { 'item' => item('Q1'), 'p' => prop('P155'), 'v' => item('Q404') }]
    when /wdt:P2669/ then [{ 'item' => item('Q1'), 'p' => prop('P571'), 'd' => { 'value' => '1977-09-11T00:00:00Z' } }]
    when /quantityAmount/ then [{
      'item'   => item('Q1'),
      'p'      => { 'value' => 'p:P2928' },
      'a'      => { 'value' => '+128' },
      'uLabel' => { 'value' => 'byte' }
    }]
    when /COUNT/ then [{ 'item' => item('Q1'), 'n' => { 'value' => '500' } }]
    else []
    end
  end

  def names
    wiki = 'https://en.wikipedia.org/wiki/Atari_2600'
    img  = 'http://commons.wikimedia.org/wiki/Special:FilePath/Atari%202600%2B.jpg'
    atari = {
      'item'      => item('Q1'),
      'itemLabel' => { 'value' => 'Atari 2600' },
      'en'        => { 'value' => wiki },
      'img'       => { 'value' => img }
    }
    [atari,
     { 'item' => item('Q4'), 'itemLabel' => { 'value' => 'Q4' } },
     { 'item' => item('Q5'), 'itemLabel' => { 'value' => '7800' }, 'hu' => { 'value' => 'Atari 7800' } }]
  end

  def post(_url, body:, **)
    query = URI.decode_www_form(body).to_h['query']
    Rubbs::Common::Web::HTTP::Response.new(
      status:  200,
      body:    JSON.generate('results' => { 'bindings' => bindings(query) }),
      headers: {}
    )
  end

  def records
    Rubbs::Common::Web::HTTP.stub(:post, ->(url, **options) { post(url, **options) }) { WikidataRepository.new(pause: 0).records }
  end

  def test_machines_are_found_merged_and_cleaned
    atari, seventy = records.sort_by { |r| r['id'] }
    assert_equal ['Q1', 'Atari 2600', 'console', 1977, 'Atari 2600'], atari.values_at('id', 't', 'k', 'y', 'w')
    assert_equal [['Atari'], ['128 B'], 500, ['Q5']], atari.values_at('mak', 'mem', 'g', 'suc')
    refute atari.key?('pre')
    assert_equal 'Atari 2600+.jpg', atari['img']
    assert_equal ['Q5', 'Atari 7800'], seventy.values_at('id', 'h')
  end

  def test_categories_and_games_are_no_machines
    assert_equal(%w[Q1 Q5], records.map { |r| r['id'] }.sort)
  end

  def test_a_failed_query_raises
    status = ->(*, **) { Rubbs::Common::Web::HTTP::Response.new(status: 502, body: '', headers: {}) }
    assert_raises(WikidataRepository::Error) { Rubbs::Common::Web::HTTP.stub(:post, status) { WikidataRepository.new(pause: 0).records } }
  end
end
