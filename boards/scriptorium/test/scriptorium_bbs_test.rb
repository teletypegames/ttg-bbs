# frozen_string_literal: true

require 'test_helper'

class ScriptoriumBBSTest < Minitest::Test
  include TempDir

  def env
    { 'SCRIPTORIUM_BBS_DB' => path('scriptorium.sqlite3'), 'SCRIPTORIUM_BBS_CATALOG_DB' => path('catalog.sqlite3'),
      'SCRIPTORIUM_BBS_TEXTS' => path('texts') }
  end

  def test_the_reads_of_an_older_board_are_imported_once
    File.write(path('reads.jsonl'), %({"at":"2026-11-01T00:19:50Z","book":11}\nnot json\n))
    bbs = nil
    _, err = capture_io { bbs = ScriptoriumBBS.new(env) }

    assert_match ': reads: imported 1 reads from reads.jsonl (1 skipped)', err
    assert_equal 1, bbs.library.reads(BookModel.stub(id: 11, title: 'Alice'))
    assert_path_exists path('reads.jsonl.imported')
    capture_io { ScriptoriumBBS.new(env) }
    assert_equal 1, ReadRepository.new(BBS::SQLite.new(path('scriptorium.sqlite3'))).count(11)
  end
end
