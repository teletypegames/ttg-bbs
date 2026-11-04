# frozen_string_literal: true

require 'bbs'
require 'domain'
require 'minitest/autorun'
require 'tmpdir'

# A temporary data folder for each test, removed after it, with the
# board's two databases in it, the models bound to them.
module TempDir
  DATABASES = { main: ['scriptorium.sqlite3', MIGRATIONS], catalog: ['catalog.sqlite3', CATALOG_MIGRATIONS] }.freeze

  def setup
    super
    @dir = Dir.mktmpdir('scriptorium-test')
    @databases = DATABASES.transform_values { |file, migrations| BBS::Database.open(path(file), migrations) }
    BBS::Model.bind(@databases)
  end

  def teardown
    @databases.each_value { |db| close_database(db) }
    FileUtils.rm_rf(@dir)
    super
  end

  def path(name) = File.join(@dir, name)

  def close_database(db)
    db.disconnect
    Sequel::DATABASES.delete(db)
  end
end
