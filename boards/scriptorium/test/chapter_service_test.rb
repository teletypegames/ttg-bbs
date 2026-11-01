# frozen_string_literal: true

require 'test_helper'

class ChapterServiceTest < Minitest::Test
  PROSE = 'It is a truth universally acknowledged, that a single man in possession of a good fortune, must be ' \
          'in want of a wife. However little known the feelings or views of such a man may be on his first ' \
          'entering a neighbourhood, this truth is so well fixed in the minds of the surrounding families.'

  def setup
    @service = ChapterService.new(chapter_max: 2_000, section: 1_000)
  end

  def book(*chapters)
    body = chapters.map { |title| "#{title}\r\n\r\n#{wrapped(PROSE)}\r\n\r\n#{wrapped(PROSE)}" }.join("\r\n\r\n\r\n")
    "﻿The Project Gutenberg eBook\r\n*** START OF THE PROJECT GUTENBERG EBOOK X ***\r\n\r\n#{body}\r\n" \
      "*** END OF THE PROJECT GUTENBERG EBOOK X ***\r\nThe licence."
  end

  def wrapped(text) = text.scan(/.{1,70}(?:\s|\z)/).map(&:strip).join("\r\n")

  def test_clean_takes_off_the_licence_and_joins_the_prose
    text = @service.clean(book('CHAPTER I', 'CHAPTER II'))

    refute_match 'Project Gutenberg', text
    refute_match 'licence', text
    assert_equal ['CHAPTER I', PROSE, PROSE, 'CHAPTER II', PROSE, PROSE], text.split("\n\n")
  end

  def test_clean_drops_control_characters_but_keeps_the_lines_of_verse
    raw = +"Line one\fof the verse\nThe second \e[2Jline\u0085\n\n\fNext\tparagraph"

    assert_equal "Line oneof the verse\nThe second [2Jline\n\nNext paragraph", @service.clean(raw)
  end

  def test_clean_reads_latin1_when_the_bytes_are_not_utf8
    assert_equal 'Café', @service.clean((+"Caf\xE9").force_encoding(Encoding::BINARY))
  end

  def test_cut_finds_the_chapters_by_their_headings
    text = @service.clean(book('CHAPTER I', 'CHAPTER II', 'CHAPTER III'))
    chapters = @service.cut(text)

    assert_equal ['CHAPTER I', 'CHAPTER II', 'CHAPTER III'], chapters.map(&:first)
    assert_equal 0, chapters.first[1]
    assert_equal text.bytesize, chapters.sum(&:last)
    assert text.byteslice(chapters[1][1], chapters[1][2]).start_with?('CHAPTER II')
  end

  def test_cut_skips_a_table_of_contents_and_joins_a_short_heading
    text = @service.clean("CONTENTS\n\nCHAPTER I\n\nCHAPTER II\n\nBOOK ONE\n\n" \
                          "CHAPTER I\n\n#{PROSE}\n\n#{PROSE}\n\nCHAPTER II\n\n#{PROSE}\n\n#{PROSE}")

    assert_equal ['BOOK ONE · CHAPTER I', 'CHAPTER II'], @service.cut(text).map(&:first)
  end

  def test_cut_parts_a_book_without_headings
    text = @service.clean(+([PROSE] * 12).join("\n\n"))
    titles = @service.cut(text).map(&:first)

    assert_operator titles.size, :>=, 2
    assert_equal "Part 1/#{titles.size}", titles.first
  end

  def test_cut_reads_a_long_chapter_in_parts
    text = @service.clean("CHAPTER I\n\n#{([PROSE] * 12).join("\n\n")}\n\nCHAPTER II\n\n#{PROSE}\n\n#{PROSE}")
    titles = @service.cut(text).map(&:first)

    assert_match %r{\ACHAPTER I \(1/\d\)\z}, titles.first
    assert_equal 'CHAPTER II', titles.last
  end

  def test_cut_of_nothing_is_nothing
    assert_empty @service.cut(@service.clean(+"*** START OF THE PROJECT GUTENBERG EBOOK X ***\n\n"))
  end
end
