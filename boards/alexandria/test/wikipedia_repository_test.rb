# frozen_string_literal: true

require 'test_helper'

class WikipediaRepositoryTest < Minitest::Test
  ARTICLE = { 'query' => { 'redirects' => [{ 'from' => "Old\e[5m" }],
                           'pages' => [{ 'pageid' => 1208, 'title' => "Ada\e]0;x\a", 'fullurl' => 'https://en.wikipedia.org/wiki/Ada',
                                         'extract' => "Lead \e[31mtext.\n\n== History ==\nBorn.\n\n== References ==\nx" }] } }
            .freeze

  HIT = { 'title' => "T\u202e", 'snippet' => 'a <b>b</b> &#27;', 'wordcount' => 9 }.freeze

  def repository = @repository ||= WikipediaRepository.new(languages: %w[en hu])

  def answers(params)
    case params['list'] || params['prop']
    when 'search' then { 'query' => { 'search' => [HIT] } }
    when 'random' then { 'query' => { 'random' => [{ 'title' => "R\e[2J" }] } }
    else ARTICLE
    end
  end

  def wiki = @wiki ||= FakeWikipedia.new { |params| answers(params) }

  def test_an_article_is_cleaned_and_cut_into_sections
    article = wiki.serve { repository.article('Ada', lang: 'en') }
    assert_equal ['Ada]0;x', 'Old[5m'], [article.title, article.redirected_from]
    assert_equal([['Ada]0;x', 'Lead [31mtext.'], ['History', 'Born.']], article.sections.map { |s| [s.title, s.markdown] })
  end

  def test_the_short_address_is_by_page_id
    article = wiki.serve { repository.article('Ada', lang: 'en') }
    assert_equal 'https://en.wikipedia.org/?curid=1208', article.short_url
    assert_equal 'https://en.wikipedia.org/wiki/Ada', article.with(pageid: nil).short_url
  end

  def test_answers_are_cached
    wiki.serve { 2.times { repository.article('Ada', lang: 'en') } }
    assert_equal 1, wiki.requests.size
  end

  def test_search_hits_are_plain_and_clean
    hit = wiki.serve { repository.search('ada', lang: 'en') }.first
    assert_equal ['T', 'a b', 9], [hit.title, hit.snippet, hit.words]
  end

  def test_a_random_title_is_clean
    assert_equal('R[2J', wiki.serve { repository.random_title(lang: 'hu') })
  end

  def test_an_unknown_language_or_no_answer_raises
    assert_raises(ArgumentError) { wiki.serve { repository.article('Ada', lang: 'xx') } }
    assert_raises(BBS::HTTP::Error) { FakeWikipedia.new(status: 500) { {} }.serve { repository.search('ada', lang: 'en') } }
  end

  def test_a_request_names_the_board_and_asks_for_json
    wiki.serve { repository.random_title(lang: 'hu') }
    uri, options = wiki.requests.first
    assert_equal ['hu.wikipedia.org', WikipediaRepository::USER_AGENT], [uri.host, options[:user_agent]]
    assert_includes uri.query, 'formatversion=2'
  end
end
