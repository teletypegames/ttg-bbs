# frozen_string_literal: true

require_relative 'test_helper'
require 'rubbs/test'
require 'tmpdir'

# The caller's Hunt page: a guest reads the first clue, an account answers
# and goes home.
class HuntTest < Minitest::Test
  HUNT = <<~YAML
    title: Test Route
    intro: A short one.
    opens: 2026-01-01 00:00
    closes: 2099-01-01 00:00
    steps:
      - clue: What is two and two?
        answer: ['4', 'four']
        fragment: FOUR
  YAML

  def setup
    Rubbs::Common::Badges.reset
    Rubbs::Test.auth_secret
    @data = Dir.mktmpdir('ttg-hunt')
    FileUtils.mkdir_p(File.join(@data, 'hunts', '2026'))
    File.write(File.join(@data, 'hunts', '2026', 'test-route.yml'), HUNT)
    Rubbs::Common::Hunt.directory = File.join(@data, 'hunts')
    @accounts = Rubbs::Test.accounts
    @ada      = @accounts.register('Ada', 'secret1')
    services  = [Rubbs::Common::Badges::Service, Rubbs::Common::Hunt::Service]
    capture_io { @server = Rubbs::Common::Central::Server.new(services: services, accounts: @accounts, data: @data) }
    Rubbs.config.central = Rubbs::Common::Central::Link.new(server: @server)
  end

  def teardown
    @server&.stop
    Rubbs.config.central = nil
    Rubbs::Common::Hunt.directory = nil
    Rubbs::Common::Badges.reset
    FileUtils.rm_rf(@data)
    Rubbs.config.auth_secrets = []
  end

  def test_a_guest_reads_the_first_clue
    line = Rubbs::Test::Session.new(keys: ['b'])
    capture_io { TTG::Hunt.open(line) }
    assert_includes line.output, 'THE HUNT: TEST ROUTE'
    assert_includes line.output, 'What is two and two?'
    assert_includes line.output, 'Make one in your profile'
  end

  def test_an_account_answers_and_goes_home
    identity = Rubbs::Common::Auth::Identity.new(id: @ada.id, name: 'Ada', source: :login)
    line = Rubbs::Test::Session.new(keys: ['a', *'four'.chars, :enter, ' ', 'b'], identity: identity)
    capture_io { TTG::Hunt.open(line) }
    assert_includes line.output, 'Right! The Hunt, Test Route: you made it home! You are number 1 this week.'
    assert_includes line.output, 'You made it home in'
    assert_includes line.output, 'Fragments: FOUR'
  end
end
