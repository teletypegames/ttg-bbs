# frozen_string_literal: true

require 'test_helper'

class ArticleServiceTest < Minitest::Test
  # Wikipedia with one article, "Ada", and one search hit for anything.
  class Wikipedia
    def article(title, lang:) = title == 'Ada' ? ArticleModel.new('Ada', 'u', lang, [], nil, 1) : nil
    def search(query, lang:) = [SearchResultModel.new("#{query} (#{lang})", '', 1)]
    def random_title(lang:) = "Random #{lang}"
  end

  def service = ArticleService.new(Wikipedia.new, languages: %w[en hu de])

  def test_a_title_opens_its_article_else_the_search
    assert_equal 'Ada', service.look_up(' Ada ', lang: 'en').first.title
    article, results = service.look_up('Babbage', lang: 'hu')
    assert_nil article
    assert_equal ['Babbage (hu)'], results.map(&:title)
  end

  # Wikipedia whose titles are case-sensitive, as they are past the first
  # letter: "jack tramiel" is no article, but a search finds "Jack Tramiel".
  class CaseSensitive
    def article(title, lang:) = title == 'Jack Tramiel' ? ArticleModel.new(title, 'u', lang, [], nil, 1) : nil
    def search(*, **) = [SearchResultModel.new('Jack Tramiel', '', 1), SearchResultModel.new('Tramiel', '', 1)]
  end

  def test_a_title_in_another_case_opens_its_article
    service = ArticleService.new(CaseSensitive.new, languages: %w[en])
    ['jack tramiel', 'JACK TRAMIEL', 'jACK tRAMIEL'].each do |typed|
      assert_equal 'Jack Tramiel', service.look_up(typed, lang: 'en').first&.title, typed
    end
    article, results = service.look_up('tramiel family', lang: 'en')
    assert_nil article
    assert_equal ['Jack Tramiel', 'Tramiel'], results.map(&:title)
  end

  def test_an_empty_query_finds_nothing
    assert_equal [nil, []], service.look_up('  ', lang: 'en')
  end

  def test_the_languages_go_round
    assert_equal(%w[hu de en], %w[en hu de].map { |lang| service.next_language(lang) })
  end

  # Wikipedia that never answers.
  class Silent
    def article(*, **) = raise(Rubbs::Common::Web::HTTP::Error, 'Wikipedia answered 503')
    alias search article
    alias random_title article
  end

  def test_no_answer_is_nil_and_logged_once
    silent = ArticleService.new(Silent.new, languages: %w[en])
    _, err = capture_io do
      assert_nil silent.random(lang: 'en')
      assert_equal [nil, nil], silent.look_up('Ada', lang: 'en')
    end
    assert_equal 3, err.lines.size
    assert_match(/: wikipedia: random: Rubbs::Common::Web::HTTP::Error: Wikipedia answered 503/, err)
  end
end
