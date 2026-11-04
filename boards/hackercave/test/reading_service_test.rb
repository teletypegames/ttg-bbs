# frozen_string_literal: true

require 'test_helper'

class ReadingServiceTest < Minitest::Test
  include TempDir

  # An RFC Editor with one text, RFC 854; any other answers 404.
  class FakeEditor
    attr_reader :fetches

    def initialize = @fetches = 0

    def text(number)
      @fetches += 1
      raise BBS::HTTP::Error, "GET rfc#{number}.txt: answered 404" unless number == 854

      +"TELNET PROTOCOL SPECIFICATION\n\fpage two\n"
    end
  end

  def setup
    super
    @editor  = FakeEditor.new
    @texts   = TextRepository.new(path('rfc'))
    @reading = ReadingService.new(texts: @texts, editor: @editor, reflow: ReflowService.new)
  end

  def test_an_rfc_is_fetched_once_kept_on_disk_and_counted_once_a_call
    seen = Set.new
    doc = @reading.open(RfcModel.stub(854), seen: seen)
    assert_equal ['TELNET PROTOCOL SPECIFICATION', 'page two'], doc.lines
    assert_equal 2, doc.pages
    assert File.exist?(path('rfc/rfc854.txt'))
    @reading.open(RfcModel.stub(854), seen: seen)
    assert_equal 1, @editor.fetches
    assert_equal 1, ReadModel.count_of(854)
  end

  def test_a_text_on_disk_is_not_fetched
    @texts.store(1, "Host Software\n")
    assert_equal ['Host Software'], @reading.open(RfcModel.stub(1)).lines
    assert_equal 0, @editor.fetches
  end

  def test_no_plain_text
    assert_equal :no_text, @reading.open(RfcModel.stub(99_998))
    assert_equal :no_text, @reading.open(RfcModel.stub(99_998))
    assert_equal 2, @editor.fetches
  end

  def test_reflowed_lines_are_kept_per_width
    doc = @reading.open(RfcModel.stub(854))
    assert_same @reading.reflowed(doc, 38), @reading.reflowed(doc, 38)
  end

  def test_mentions_and_contents
    @texts.store(2, "INTRODUCTION\n\n   See RFC 793 and [RFC2119], IEN 116, and RFC 793 again.\n\n" \
                    "1.  Scope\n\n   This RFC 2 names itself.\n")
    doc = @reading.open(RfcModel.stub(2))
    assert_equal [[793, 2], [2119, 2], [-116, 2]], @reading.mentions(doc)
    assert_equal [[0, 'INTRODUCTION'], [4, '1.  Scope']], @reading.contents(doc)
  end
end
