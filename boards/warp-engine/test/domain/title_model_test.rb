# frozen_string_literal: true

require 'test_helper'

class TitleModelTest < Minitest::Test
  def test_parses_an_index_line
    title = TitleModel.parse(BoardTest.line, BoardTest::SHELF)

    assert_equal 'GAME.PRG', title.file
    assert_equal 4, title.size
    assert_equal 'c64/GAME.PRG', title.key
    assert_equal 'GAME', title.disk_name
    assert_equal 'A game.', title.about
  end

  def test_skips_comments_and_broken_lines
    assert_nil TitleModel.parse("#SHELF 1\n", BoardTest::SHELF)
    assert_nil TitleModel.parse("GAME.PRG|1.0|big|00000000|Game|Me|About\n", BoardTest::SHELF)
    assert_nil TitleModel.parse("GAME.PRG|1.0|4\n", BoardTest::SHELF)
  end

  def test_encodes_the_file_name_in_its_path
    title = TitleModel.parse(BoardTest.line(file: 'MY GAME?/../X.PRG'), BoardTest::SHELF)

    assert_equal '/C64/MY%20GAME%3F%2F..%2FX.PRG', title.path
  end
end
