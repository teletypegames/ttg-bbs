# frozen_string_literal: true

require 'test_helper'

class HtmlTextTest < Minitest::Test
  def test_paragraphs_headings_lists_and_quotes
    md = HtmlText.markdown('<h2>News</h2><p>One</p><ul><li>a</li><li>b</li></ul><blockquote><p>said</p></blockquote>')
    assert_equal "### News\n\nOne\n\n- a\n\n- b\n\n> said", md
  end

  def test_links_are_numbered_and_listed
    md = HtmlText.markdown('<p>See <a href="https://a.example/x">this</a> and <a href="https://a.example/x">it</a>.</p>')
    assert_equal "See this[1] and it[1].\n\n### Links\n\n\\[1] https://a.example/x", md
  end

  def test_a_link_nowhere_keeps_its_text
    assert_equal 'run', HtmlText.markdown('<a href="javascript:alert(1)">run</a>')
  end

  def test_scripts_comments_and_images
    md = HtmlText.markdown('<script>x()</script><!-- c --><p><img alt="cat" src="c.png"> sat</p>')
    assert_equal '[cat] sat', md
  end

  def test_control_characters_go
    assert_equal 'a]52;c;b[2Jc', HtmlText.plain("a\e]52;c;\a\u202Eb\e[2J&#27;c")
    assert_equal 'xy', HtmlText.markdown('<p>x&#x9b;&#0;y</p>')
  end

  def test_entities
    html = '&Aacute;rv&iacute;zt&udblac;r&odblac; &ndash; &bdquo;t&uuml;k&ouml;r&rdquo;'
    assert_equal 'Árvíztűrő – „tükör”', HtmlText.plain(html)
  end

  def test_markdown_signs_in_text_are_escaped
    assert_equal '\\# not a heading', HtmlText.markdown('<p># not a heading</p>')
  end
end
