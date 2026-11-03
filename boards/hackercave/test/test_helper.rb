# frozen_string_literal: true

require 'bbs'
require 'domain'
require 'minitest/autorun'
require 'tmpdir'

FIXTURES = File.expand_path('fixtures', __dir__)

# A temporary data folder for each test, removed after it.
module TempDir
  def setup
    super
    @dir = Dir.mktmpdir('hackercave-test')
  end

  def teardown
    FileUtils.rm_rf(@dir)
    super
  end

  def path(name) = File.join(@dir, name)

  # A database with the board's schema.
  def database
    BBS::SQLite.new(path('hackercave.sqlite3')).tap { |db| db.migrate(*ReadRepository::MIGRATIONS) }
  end

  # The index of test/fixtures: rfc-index.xml, errata.json and the IENs.
  def index
    IndexRepository.new(path('index.sqlite3')).tap do |i|
      i.import(fixture('rfc-index.xml'), errata: fixture('errata.json'), iens: ien_index)
    end
  end

  def ien_index
    IenIndex.new(File.read(fixture('ien-index.txt')), texts: IenIndex.texts_in(File.read(fixture('ien-listing.html'))))
  end

  def fixture(name) = File.join(FIXTURES, name)
end
