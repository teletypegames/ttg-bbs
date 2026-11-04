# frozen_string_literal: true

require 'bbs'
require 'domain'
require 'minitest/autorun'
require 'tmpdir'

FIXTURES = File.expand_path('fixtures', __dir__)

# A temporary data folder for each test, removed after it, with the
# board's four databases in it, the models bound to them.
module TempDir
  DATABASES = { main: ['hackercave.sqlite3', MIGRATIONS], index: ['index.sqlite3', INDEX_MIGRATIONS],
                fulltext: ['fulltext.sqlite3', FULLTEXT_MIGRATIONS], jargon: ['jargon.sqlite3', JARGON_MIGRATIONS] }.freeze

  def setup
    super
    @dir = Dir.mktmpdir('hackercave-test')
    @databases = DATABASES.transform_values { |file, migrations| open_database(file, migrations) }
    BBS::Model.bind(@databases)
  end

  def teardown
    @databases.each_value { |db| close_database(db) }
    FileUtils.rm_rf(@dir)
    super
  end

  def path(name) = File.join(@dir, name)

  # The database +file+ of the folder, migrated by +migrations+, and the
  # models of +name+ bound to it.
  def open_database(file, migrations, name: nil)
    db = BBS::Database.open(path(file), migrations)
    BBS::Model.bind(name => db) if name
    db
  end

  def close_database(db)
    db.disconnect
    Sequel::DATABASES.delete(db)
  end

  # The index of test/fixtures: rfc-index.xml, errata.json and the IENs.
  # Returns the number of RFCs imported.
  def index
    IndexBuilder.new.build(fixture('rfc-index.xml'), errata: fixture('errata.json'), iens: ien_index)
  end

  def ien_index
    IenIndex.new(File.read(fixture('ien-index.txt')), texts: IenIndex.texts_in(File.read(fixture('ien-listing.html'))))
  end

  def fixture(name) = File.join(FIXTURES, name)
end
