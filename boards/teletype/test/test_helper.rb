# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../lib/domain'

# A fresh database in a temporary directory for each test.
module DatabaseCase
  def setup
    super
    @dir = Dir.mktmpdir('teletype-test')
    @db  = Database.open(File.join(@dir, 'teletype.sqlite3'))
  end

  def teardown
    @db&.close
    FileUtils.rm_rf(@dir)
    super
  end
end
