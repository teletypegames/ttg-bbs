# frozen_string_literal: true

require 'test_helper'

class ArticleModelTest < Minitest::Test
  def answer(extract)
    { 'query' => { 'redirects' => [{ 'from' => 'Tribbles' }],
                   'pages' => [{ 'pageid' => 454, 'title' => 'The Trouble with Tribbles (episode)',
                                 'fullurl' => 'https://memory-alpha.fandom.com/wiki/The_Trouble_with_Tribbles_(episode)',
                                 'extract' => extract }] } }
  end

  def test_an_article_cut_into_sections_without_the_links
    article = ArticleModel.from_api(answer("Furry.\n== Summary ==\nTribbles.\n== Links and references ==\nx"))
    assert_equal ['The Trouble with Tribbles (episode)', 'Summary'], article.sections.map(&:title)
    assert_equal 'Tribbles', article.redirected_from
    assert_equal 'https://memory-alpha.fandom.com/?curid=454', article.short_url
  end

  def test_a_missing_page_is_nil
    assert_nil ArticleModel.from_api({ 'query' => { 'pages' => [{ 'title' => 'X', 'missing' => true }] } })
    assert_nil ArticleModel.from_api(answer(' '))
  end
end
