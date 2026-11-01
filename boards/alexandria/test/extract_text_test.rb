# frozen_string_literal: true

require 'test_helper'

class ExtractTextTest < Minitest::Test
  def test_sections_skip_the_references_and_keep_deeper_headings
    extract = "Lead.\n== History ==\n=== Early ===\nBorn.\n== See also ==\nx"
    assert_equal [['Ada', 'Lead.'], ['History', "## Early\n\nBorn."]], ExtractText.sections('Ada', extract)
  end

  def test_a_formula_becomes_its_tex_made_readable
    assert_equal [['F', 'x = α +1 ok']], ExtractText.sections('F', 'x = {\\displaystyle \\alpha +1} ok')
  end

  def test_a_line_that_looks_like_markdown_is_escaped
    assert_equal [['T', "\\#tag\n\n\\> quote"]], ExtractText.sections('T', "#tag\n> quote")
  end
end
