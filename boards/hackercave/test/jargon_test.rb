# frozen_string_literal: true

require 'test_helper'

class JargonTest < Minitest::Test
  include TempDir

  def jargon(clock: -> { Time.new(2026, 11, 3) })
    JargonService.new(file: JargonFileRepository.new(fixture('jargon.txt')), clock: clock, random: Random.new(1)).tap(&:prepare)
  end

  def test_the_entries_by_letter
    j = jargon
    assert_equal 3, j.count
    assert_equal [['H', 2], ['K', 1]], j.letters
    kluge = j.letter('K').first
    assert_equal ['kluge', '/klooj/'], [kluge.headword, kluge.pron]
    assert_equal %i[text text pre], kluge.paragraphs.map(&:first)
    assert_equal "if (x) { y(); }\nelse z();", kluge.paragraphs.last.last
  end

  def test_links_to_the_entries_that_exist
    hack = jargon.letter('H').first
    assert_equal '1. n. Originally, a quick job that produces what is needed, but not well. See kluge, hacker and ' \
                 'nowhere.',
                 hack.summary
    assert_equal %w[kluge hacker], jargon.links(hack).map(&:headword)
  end

  def test_latin1_search_and_the_sections
    j = jargon
    assert_includes j.letter('H').last.summary, 'Café culture.'
    assert_equal ['hacker'], j.search('cafe').map(&:headword)
    assert_equal 'hack', j.search('hack').first.headword
    assert_equal :too_short, j.search('a')
    titles = j.sections.map(&:title)
    assert_equal ['Welcome to the Jargon File', 'Chapter 1. Hacker Slang and Hacker Culture', 'Appendix A. Hacker Folklore'],
                 titles
    assert_equal [:heading, 'The Story of Mel'], j.sections.last.paragraphs.first
  end

  def test_word_of_the_day_is_the_same_all_day_and_the_file_is_read_once
    assert_equal jargon.word_of_the_day, jargon(clock: -> { Time.new(2026, 11, 3, 23, 59) }).word_of_the_day
    assert_equal :fresh, jargon.prepare
    assert jargon.random
  end

  def test_a_new_file_is_built_in_place_of_the_old
    jargon
    File.write(path('jargon.txt'), File.binread(fixture('jargon.txt')).sub(':kluge:', ':kludge:'))
    j = JargonService.new(file: JargonFileRepository.new(path('jargon.txt')))
    assert_equal :built, j.prepare
    assert_equal ['kludge'], j.letter('K').map(&:headword)
    assert_equal 3, j.count
    assert_equal 3, j.sections.size
  end
end
