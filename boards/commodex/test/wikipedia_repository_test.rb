# frozen_string_literal: true

require 'test_helper'

class WikipediaRepositoryTest < Minitest::Test
  LEAD = { 'query' => { 'pages' => [{
    'title'   => "Elite\e]0;x\a",
    'fullurl' => 'https://en.wikipedia.org/wiki/Elite',
    'extract' => "First \e[31mpara.\n\nSecond  para."
  }] } }.freeze

  def repository = @repository ||= WikipediaRepository.new

  def test_a_lead_is_cleaned_into_paragraphs_and_cached
    wiki = FakeWikipedia.new { LEAD }
    summary = wiki.serve { 2.times.map { repository.summary('Elite') }.last }
    assert_equal ['Elite]0;x', ['First [31mpara.', 'Second para.']], [summary.title, summary.paragraphs]
    assert_equal 1, wiki.requests.size
  end

  def test_a_missing_article_and_no_answer
    missing = FakeWikipedia.new { { 'query' => { 'pages' => [{ 'missing' => true }] } } }
    assert_equal(:missing, missing.serve { repository.summary('Nope') })
    assert_raises(BBS::HTTP::Error) { FakeWikipedia.new(status: 503) { {} }.serve { repository.summary('Elite') } }
  end

  def test_the_about_service_says_why_not
    about = AboutService.new(repository)
    elite = game('Q2', 'Elite', 'w' => 'Elite')
    assert_equal :no_article, about.summary(game('Q1', 'Zork'))
    _, err = capture_io { assert_equal(:unavailable, FakeWikipedia.new(status: 503) { {} }.serve { about.summary(elite) }) }
    assert_match(/: wikipedia: Elite: Wikipedia answered 503/, err)
  end
end
