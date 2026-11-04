# frozen_string_literal: true

require 'minitest/autorun'
require 'bbs'
require 'bbs/test'
require 'domain'
require 'minitest/mock'
require 'tmpdir'

# A shelf, a title line and a fresh database in a temporary folder, for
# every test.
module BoardTest
  SHELF = ShelfModel.new(id: 'c64', name: 'Commodore 64', path: '/C64', about: 'C64 titles.')

  def self.line(file: 'GAME.PRG', size: 4, crc32: Zlib.crc32('GAME'), title: 'Game')
    "#{file}|1.0|#{size}|#{format('%08x', crc32)}|#{title}|Teletype|A game.\n"
  end

  def setup
    @dir = Dir.mktmpdir
    BBS::Test.database(MIGRATIONS)
    super
  end

  def teardown
    super
    FileUtils.remove_entry(@dir)
  end

  def response(body, status: 200) = BBS::HTTP::Response.new(status: status, body: body.b, headers: {})
end
