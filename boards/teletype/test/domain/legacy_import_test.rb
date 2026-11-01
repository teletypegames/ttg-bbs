# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../support/legacy_fixtures'

class LegacyImportTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('teletype-legacy')
    LegacyFixtures.write(@dir)
    @log = []
  end

  def teardown
    @db&.close
    FileUtils.rm_rf(@dir)
  end

  def open_db
    @db = BBS::SQLite.new(File.join(@dir, 'teletype.sqlite3'))
    @db.migrate(*Database::SCHEMA)
    LegacyImport.new(@db, @dir, log: ->(line) { @log << line }).run
  end

  def test_counts_every_good_row_and_skips_the_torn_ones
    counts = open_db
    assert_equal [2, 1], counts['accounts']
    assert_equal [4, 1], counts['posts']
    assert_equal [3, 1], counts['calls']
    assert_equal [1, 1], counts['oneliners']
    assert_equal [2, 1], counts['trivia_scores']
    assert_equal [3, 0], counts['votes']
    assert_equal [2, 0], counts['mail']
    assert_equal [1, 0], counts['profiles']
    assert_equal [2, 0], counts['last_read']
    assert_match(/posts 4 \(1 unreadable skipped\)/, @log.first)
  end

  def test_renames_the_files_and_leaves_the_archive_alone
    open_db
    %w[accounts.csv boards/general.csv boards/tech.csv last_callers.csv mail.csv].each do |name|
      refute File.exist?(File.join(@dir, name)), name
      assert File.exist?(File.join(@dir, "#{name}.imported")), name
    end
    assert File.exist?(File.join(@dir, 'archive/old.csv'))
  end

  def test_a_second_start_imports_nothing
    open_db
    assert_empty LegacyImport.new(@db, @dir, log: ->(line) { @log << line }).run
  end

  def test_imported_passwords_still_log_on
    open_db
    accounts = AccountService.new(AccountRepository.new(@db), pause: ->(_) {})
    assert_equal :ok, accounts.log_on('tasi', caller_key: '1.2.3.4') { LegacyFixtures::PASSWORD }
    assert_equal 'Tasi', accounts.canonical('TASI')
  end

  def test_posts_keep_their_content
    open_db
    boards = BoardRepository.new(@db)
    assert_equal ['hello', 'with, a comma', 'guest post'], boards.last('general').map(&:text)
    assert_equal "a post\nof two lines", boards.last('tech').first.text
  end

  def test_rows_keep_their_content
    open_db
    assert_equal 'TTG Trivia', VoteRepository.new(@db).ballot('favourite', 'Tasi')
    assert_equal "two\nlines", MailRepository.new(@db).to(['tasi']).first.body
    assert_equal 'Budapest', ProfileRepository.new(@db).find('tasi')['location']
    assert_equal 120 + 0, LastCallersRepository.new(@db).stats('tasi').seconds
  end

  def test_profiles_from_the_rubbs_store
    File.delete(File.join(@dir, 'profiles.csv'))
    store = BBS::Store.new(path: File.join(@dir, 'profiles.sqlite3'), headers: %w[session_id timestamp username location])
    store.upsert(session_id: 'user-kali', username: 'Kali', location: 'Szeged')
    open_db
    assert_equal 'Szeged', ProfileRepository.new(@db).find('kali')['location']
    assert File.exist?(File.join(@dir, 'profiles.sqlite3.imported'))
  end

  def test_csv_rows_resume_after_a_broken_line
    rows, skipped = LegacyImport.csv_rows(%(a,"b\nc",d\ne,f\n))
    assert_equal [%W[a b\nc d], %w[e f]], rows
    assert_equal 0, skipped
    rows, skipped = LegacyImport.csv_rows(%(a,"b\nc,d\ne,f\n))
    assert_equal [%w[c d], %w[e f]], rows
    assert_equal 1, skipped
    rows, skipped = LegacyImport.csv_rows(%(a,b"c\nd,e\n))
    assert_equal [%w[d e]], rows
    assert_equal 1, skipped
  end
end
