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

# The accounts of the network for a test (BBS::Test.accounts), the board's
# login (BBS.config.auth) on them; forgotten after the test.
module AccountsCase
  def accounts
    @accounts ||= BBS::Test.accounts(roles: %w[member]).tap do |directory|
      BBS.config.auth = BBS::Auth::Setup.new(directory: directory, login: :menu, guests: true)
    end
  end

  # The account +name+ with +roles+, its BBS::Auth::Identity.
  def account(name, *roles, password: 'password')
    accounts.register(name, password)
    roles.each { |role| accounts.grant(name, role) }
    accounts.find(name)
  end

  def teardown
    BBS.config.auth = nil
    super
  end
end
