# frozen_string_literal: true

require 'bbs'
require 'domain'
require 'minitest/autorun'
require 'tmpdir'

# A temporary data folder for each test, removed after it.
module TempDir
  def setup
    super
    @dir = Dir.mktmpdir('scriptorium-test')
  end

  def teardown
    FileUtils.rm_rf(@dir)
    super
  end

  def path(name) = File.join(@dir, name)

  # A database with the board's schema.
  def database
    BBS::SQLite.new(path('scriptorium.sqlite3')).tap { |db| db.migrate(*ReadRepository::MIGRATIONS) }
  end
end
