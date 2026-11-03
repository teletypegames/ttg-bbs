# frozen_string_literal: true

require 'test_helper'

class DocumentModelTest < Minitest::Test
  def test_pages_end_at_form_feeds
    doc = DocumentModel.parse(1, "one\r\ntwo   \n\fthree\n\f\nfour\n\n\n")
    assert_equal ['one', 'two', 'three', '', 'four'], doc.lines
    assert_equal [2, 3], doc.breaks
    assert_equal 3, doc.pages
    assert_equal 1, doc.page_of(1)
    assert_equal 3, doc.page_of(4)
  end

  def test_a_byte_order_mark_tabs_and_controls_go
    doc = DocumentModel.parse(9000, "﻿title\na\tb\x07c")
    assert_equal ['title', 'a       bc'], doc.lines
    refute doc.paged?
  end
end
