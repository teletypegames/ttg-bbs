# frozen_string_literal: true

require 'test_helper'

class ReflowServiceTest < Minitest::Test
  PROSE = "   The purpose of the TELNET Protocol is to provide a fairly general,\n   " \
          "bi-directional, eight-bit byte oriented communications facility.\n"

  def reflow(text, width = 38) = ReflowService.new.reflow(DocumentModel.parse(1, text), width)

  def texts(lines) = lines.map(&:text)

  def test_prose_is_joined_and_wrapped
    lines = reflow(PROSE)
    assert(lines.all? { |l| l.kind == :text && l.text.length <= 38 })
    assert_equal 'The purpose of the TELNET Protocol is', lines.first.text
    assert_equal 'oriented communications facility.', lines.last.text
  end

  def test_a_list_item_hangs
    text = "      1. When a TELNET connection is first established, each end is\n         " \
           "assumed to originate and terminate at a Network Virtual Terminal.\n"
    lines = texts(reflow(text))
    assert_equal '  1. When a TELNET connection is first', lines.first
    assert(lines.drop(1).all? { |l| l.start_with?('     ') })
  end

  def test_a_heading_at_the_margin
    lines = reflow("INTRODUCTION\n\n#{PROSE}")
    assert_equal %i[heading blank], lines.first(2).map(&:kind)
  end

  def test_short_lines_are_kept
    lines = reflow("   Information Sciences Institute\n   University of Southern California\n")
    assert_equal ['Information Sciences Institute', 'University of Southern California'], texts(lines)
    assert(lines.all? { |l| l.kind == :figure })
  end

  def test_dot_leaders_get_short
    assert_equal ['1.1  Motivation .. 1'], texts(reflow("  1.1  Motivation #{'.' * 50} 1\n"))
  end

  def test_a_wide_box_drawing_comes_in_panels
    box = "   +#{'-+' * 32}\n   |#{' ' * 20}Source Port#{' ' * 10}|#{' ' * 20}Destination|\n   +#{'-+' * 32}\n"
    lines = reflow(box)
    assert(lines.all? { |l| l.text.length <= 38 })
    assert_equal '(columns 39-75)', lines[3].text
    assert_equal :more, lines[3].kind
    assert_equal 7, lines.size
  end

  def test_a_wide_line_breaks_at_its_columns
    lines = reflow("Network Working Group                                          J. Postel\n" \
                   "Request for Comments: 854                                    J. Reynolds\n")
    assert_equal ['Network Working Group', '  J. Postel', 'Request for Comments: 854', '  J. Reynolds'], texts(lines)
  end

  def test_the_head_and_foot_of_a_page_go_and_a_broken_paragraph_joins
    text = "   This paragraph is long enough to be prose and it goes on and on and\n   " \
           "on to the next page of the document, where it goes on and it\n\n" \
           "Postel & Reynolds                                               [Page 1]\n" \
           "\f\nRFC 854                                                         May 1983\n\n   " \
           "ends after a few more words.\n"
    lines = texts(reflow(text))
    assert_equal 'This paragraph is long enough to be', lines.first
    assert_equal 'more words.', lines.last
    refute_includes lines, ''
    refute(lines.any? { |l| l.include?('Page 1') || l.include?('May 1983') })
  end

  def test_kinds_of_the_published_lines
    doc = DocumentModel.parse(1, "INTRODUCTION\n\n#{PROSE}\nPostel                                [Page 1]\n\f" \
                                 "RFC 854            May 1983\n\nmore\n")
    assert_equal %i[heading text text text text page page text heading], ReflowService.new.kinds(doc)
  end
end
