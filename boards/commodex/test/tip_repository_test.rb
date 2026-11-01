# frozen_string_literal: true

require 'test_helper'
require 'sqlite3'

class TipRepositoryTest < Minitest::Test
  include TmpData

  # The tips file as the board wrote it before it had versions.
  def legacy_file
    db = SQLite3::Database.new(path('tips.sqlite3'))
    db.execute_batch(TipRepository::MIGRATIONS.first.gsub(' IF NOT EXISTS', ''))
    db.execute("INSERT INTO tips (game_id, handle, text, status, created_at, seed) VALUES
                ('Q1', 'ada', 'POKE 53280,0', 'approved', '2026-10-01T10:00:00Z', NULL),
                ('Q1', '', 'seeded', 'approved', '2026-10-01T10:00:00Z', 'q1-a'),
                ('Q2', 'bob', 'wait', 'pending', '2026-10-02T10:00:00Z', NULL)")
    db.close
  end

  def test_a_legacy_file_keeps_its_tips_and_gets_version_one
    legacy_file
    db = BBS::SQLite.new(path('tips.sqlite3'))
    assert_equal 0, db.version
    repository = TipRepository.new(db)
    assert_equal 1, db.version
    assert_equal ['POKE 53280,0', 'seeded'], repository.approved('Q1').map(&:text)
    assert_equal 1, repository.with_status('pending').size
  end

  def test_a_new_file_gets_the_schema
    db = BBS::SQLite.new(path('new.sqlite3'))
    repository = TipRepository.new(db)
    assert_equal 1, db.version
    id = repository.insert(game_id: 'Q9', handle: 'x', text: 'tip')
    assert_equal 'pending', repository.find(id).status
  end

  def test_a_seed_goes_in_once
    repository = TipRepository.new(BBS::SQLite.new(path('tips.sqlite3')))
    2.times { repository.insert(game_id: 'Q1', handle: '', text: 'seeded', status: 'approved', seed: 'k') }
    assert_equal 1, repository.count_approved('Q1')
  end

  def test_a_status_changes_and_a_missing_tip_says_so
    repository = TipRepository.new(BBS::SQLite.new(path('tips.sqlite3')))
    id = repository.insert(game_id: 'Q1', handle: '', text: 'tip')
    assert_equal [1, 0], [repository.change_status(id, 'approved'), repository.change_status(999, 'approved')]
    assert_equal({ 'Q1' => 1 }, repository.approved_counts)
  end
end
