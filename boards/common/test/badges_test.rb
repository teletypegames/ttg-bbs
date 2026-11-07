# frozen_string_literal: true

require_relative 'test_helper'
require 'rubbs/test'
require 'tmpdir'

# The network's badges: whole by the catalog's checks, what came before them
# on the Central (Pioneer, the old notes), and the caller's list.
class BadgesTest < Minitest::Test
  NETWORK = File.expand_path('../lib/ttg/badges/network.rb', __dir__)

  def setup
    Rubbs::Common::Badges.reset
    load NETWORK
    Rubbs::Common::Badges.catalog.boards = TTG::Badges.boards
    Rubbs::Test.auth_secret
    @data     = Dir.mktmpdir('ttg-badges')
    @accounts = Rubbs::Test.accounts
    @ada      = @accounts.register('Ada', 'secret1')
  end

  def teardown
    @server&.stop
    Rubbs.config.central = nil
    Rubbs::Common::Badges.reset
    FileUtils.rm_rf(@data)
    Rubbs.config.auth_secrets = []
  end

  def central(*services)
    @server&.stop
    @server = Rubbs::Common::Central::Server.new(services: services, accounts: @accounts, data: @data)
    Rubbs.config.central = Rubbs::Common::Central::Link.new(server: @server)
  end

  def ada = Rubbs::Common::Central::Actor.new(id: @ada.id, name: 'Ada', caller_key: 'line:1')

  def test_the_badges_are_whole
    assert_empty Rubbs::Common::Badges.catalog.problems
    assert_includes TTG::Badges.boards, 'ttg-gate'
    assert_operator TTG::Badges.boards.size, :>=, 14
  end

  def test_what_came_before_the_badges
    central(TTG::Wall::Service)
    capture_io { Rubbs.central(TTG::Wall::Service).call(:post, ada, text: 'Hello from before') }
    capture_io { central(TTG::Wall::Service, TTG::Badges::Service) }
    mine = capture_io { @answer = Rubbs.central(Rubbs::Common::Badges::Service).mine(ada) } && @answer['badges']
    earned = mine.select { |b| b['earned'].any? }.map { |b| b['key'] }
    assert_equal %w[graffiti pioneer], earned.sort
  end

  def test_the_callers_list
    capture_io { central(TTG::Badges::Service) }
    identity = Rubbs::Common::Auth::Identity.new(id: @ada.id, name: 'Ada', source: :login)
    line = Rubbs::Test::Session.new(keys: ['n', 'h', ' ', 'b'], identity: identity)
    capture_io { TTG::Badges::Screen.new(line).run }
    out = line.output
    assert_includes out, '1 of '
    assert_includes out, 'Pioneer'
    assert_includes out, '???'
    assert_includes out, 'HALL OF BADGES'
  end
end
