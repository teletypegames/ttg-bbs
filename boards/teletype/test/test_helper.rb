# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../lib/domain'
require 'rubbs/test'

# A fresh database for each test, the models bound to it.
module DatabaseCase
  def setup
    super
    @db = Rubbs::Test.database(MIGRATIONS)
  end

  def teardown
    @db&.disconnect
    super
  end
end

# The accounts of the network for a test (Rubbs::Test.accounts), the board's
# login (Rubbs.config.auth) on them; forgotten after the test.
module AccountsCase
  def accounts
    @accounts ||= Rubbs::Test.accounts(roles: %w[member]).tap do |directory|
      Rubbs.config.auth = Rubbs::Common::Auth::Setup.new(directory: directory, login: :menu, guests: true)
    end
  end

  # The account +name+ with +roles+, its Rubbs::Common::Auth::Identity.
  def account(name, *roles, password: 'password')
    accounts.register(name, password)
    roles.each { |role| accounts.grant(name, role) }
    accounts.find(name)
  end

  def teardown
    Rubbs.config.auth = nil
    super
  end
end
