# frozen_string_literal: true

require 'test_helper'

class ScriptoriumBBSTest < Minitest::Test
  include TempDir

  ENV_NAMES = { 'DB' => 'scriptorium.sqlite3', 'CATALOG_DB' => 'catalog.sqlite3', 'TEXTS' => 'texts' }.freeze

  def setup
    super
    ENV_NAMES.each { |name, file| ENV["SCRIPTORIUM_BBS_#{name}"] = path(file) }
  end

  def teardown
    ENV_NAMES.each_key { |name| ENV.delete("SCRIPTORIUM_BBS_#{name}") }
    super
  end

  def test_the_reads_of_an_older_board_are_imported_once
    File.write(path('reads.jsonl'), %({"at":"2026-11-01T00:19:50Z","book":11}\nnot json\n))
    bbs = ScriptoriumBBS.new
    _, err = capture_io { bbs.services }

    assert_match ': reads: imported 1 reads from reads.jsonl (1 skipped)', err
    assert_equal 1, bbs.library.reads(BookModel.stub(id: 11, title: 'Alice'))
    assert_path_exists path('reads.jsonl.imported')
    capture_io { ScriptoriumBBS.new.services }
    assert_equal 1, ReadRepository.new(BBS::SQLite.new(path('scriptorium.sqlite3'))).count(11)
  end
end
