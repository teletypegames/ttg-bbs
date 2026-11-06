# frozen_string_literal: true

require 'test_helper'
require 'sqlite3'

class TipModelTest < Minitest::Test
  include TmpData

  # The tips file as the board wrote it before it had versions.
  def legacy_file
    db = SQLite3::Database.new(path('tips.sqlite3'))
    db.execute_batch(MIGRATIONS.first.gsub(' IF NOT EXISTS', ''))
    db.execute("INSERT INTO tips (game_id, handle, text, status, created_at, seed) VALUES
                ('Q1', 'ada', 'POKE 53280,0', 'approved', '2026-10-01T10:00:00Z', NULL),
                ('Q1', '', 'seeded', 'approved', '2026-10-01T10:00:00Z', 'q1-a'),
                ('Q2', 'bob', 'wait', 'pending', '2026-10-02T10:00:00Z', NULL)")
    db.close
  end

  def open_file(name)
    Rubbs::Common::Storage::Database.open(path(name), MIGRATIONS).tap { |db| Rubbs::Common::Storage::Model.bind(main: db) }
  end

  def test_a_legacy_file_keeps_its_tips_and_gets_version_one
    legacy_file
    assert_equal 1, Rubbs::Common::Storage::Database.version(open_file('tips.sqlite3'))
    assert_equal ['POKE 53280,0', 'seeded'], TipModel.approved('Q1').map(&:text)
    assert_equal 1, TipModel.with_status('pending').size
  end

  def test_a_new_file_gets_the_schema
    assert_equal 1, Rubbs::Common::Storage::Database.version(open_file('new.sqlite3'))
    id = TipModel.add(game_id: 'Q9', handle: 'x', text: 'tip')
    assert_equal %w[pending x x], [TipModel[id].status, TipModel[id].author, TipModel[id].handle]
  end

  def test_a_seed_goes_in_once
    open_file('tips.sqlite3')
    2.times { TipModel.add(game_id: 'Q1', handle: '', text: 'seeded', status: 'approved', seed: 'k') }
    assert_equal 1, TipModel.count_approved('Q1')
    assert_equal 'anonymous', TipModel.approved('Q1').first.author
  end

  def test_a_status_changes_and_a_missing_tip_says_so
    open_file('tips.sqlite3')
    id = TipModel.add(game_id: 'Q1', handle: '', text: 'tip')
    assert_equal [1, 0], [TipModel.change_status(id, 'approved'), TipModel.change_status(999, 'approved')]
    assert_equal({ 'Q1' => 1 }, TipModel.approved_counts)
  end
end
