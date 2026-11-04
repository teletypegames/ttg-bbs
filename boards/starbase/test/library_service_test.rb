# frozen_string_literal: true

require 'test_helper'

class LibraryServiceTest < Minitest::Test
  # Memory Alpha with two articles, case-sensitive titles, and a search
  # that finds Data for anything.
  class Alpha
    ARTICLES = ['Data', 'Encounter at Farpoint (episode)'].freeze

    def article(title) = ARTICLES.include?(title) ? ArticleModel.new(title, 'u', 1, [], nil) : nil
    def search(_query) = [SearchResultModel.new('Data', 100)]
    def random_title = 'Data'
  end

  def library = LibraryService.new(Alpha.new)

  def test_a_title_in_another_case_opens_its_article
    assert_equal 'Data', library.look_up('data').first&.title
    article, results = library.look_up('androids')
    assert_nil article
    assert_equal ['Data'], results.map(&:title)
  end

  def test_an_episode_opens_the_article_wikidata_names_else_a_search_hit
    farpoint = EpisodeModel.from_record({
      'id' => 'Q1',
      't'  => 'Encounter at Farpoint',
      'se' => 'x',
      'ma' => 'Encounter at Farpoint (episode)'
    })
    assert_equal 'Encounter at Farpoint (episode)', library.article_of(farpoint).title
    unnamed = EpisodeModel.from_record({ 'id' => 'Q2', 't' => 'Datalore', 'se' => 'x' })
    assert_equal 'Data', library.article_of(unnamed).title
  end

  # Memory Alpha that never answers.
  class Silent
    def article(*) = raise(BBS::HTTP::Error, 'Memory Alpha answered 503')
    alias search article
    def random_title = article
  end

  def test_no_answer_is_nil_and_logged
    silent = LibraryService.new(Silent.new)
    _, err = capture_io do
      assert_nil silent.random
      assert_equal [nil, nil], silent.look_up('Data')
    end
    assert_match(/memory-alpha: random: BBS::HTTP::Error: Memory Alpha answered 503/, err)
  end
end
