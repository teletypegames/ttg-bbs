# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../lib/domain'
require 'bbs/test'

# A fresh database for each test, the models bound to it.
module DatabaseCase
  def setup
    super
    @db = BBS::Test.database(MIGRATIONS)
  end

  def teardown
    @db&.disconnect
    super
  end
end
