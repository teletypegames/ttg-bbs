# frozen_string_literal: true

require 'test_helper'

class ArticleServiceTest < Minitest::Test
  # Wikipedia with one article, "Ada", and one search hit for anything.
  class Wikipedia
    def article(title, lang:) = title == 'Ada' ? ArticleModel.new('Ada', 'u', lang, [], nil) : nil
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

  def test_an_empty_query_finds_nothing
    assert_equal [nil, []], service.look_up('  ', lang: 'en')
  end

  def test_the_languages_go_round
    assert_equal(%w[hu de en], %w[en hu de].map { |lang| service.next_language(lang) })
  end
end
