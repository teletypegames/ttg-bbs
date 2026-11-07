# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'

# The hunts of content/hunts: none has a problem, and each can be played
# home on the Central with the events and answers its own file names.
class HuntTest < Minitest::Test
  Hunt = Rubbs::Common::Hunt

  def setup
    Rubbs::Common::Badges.reset
    load File.join(TTG::Badges::BOARDS, 'common', 'lib', 'ttg', 'badges', 'network.rb')
    Dir.glob(File.join(TTG::Badges::BOARDS, '*', 'badges.rb')).each { |file| load file }
    Rubbs::Test.auth_secret
  end

  def teardown
    @server&.stop
    Rubbs::Common::Badges.reset
    Rubbs.config.auth_secrets = []
  end

  def test_the_hunts_are_whole
    assert_empty Hunt::Book.new(TTG::Hunt::DIR).problems
    refute_empty Hunt::Book.new(TTG::Hunt::DIR).trails
  end

  def test_every_hunt_can_be_played_home
    accounts = Rubbs::Test.accounts
    book     = Hunt::Book.new(TTG::Hunt::DIR)
    services = [TTG::Badges::Service, Hunt::Service]
    @server  = Rubbs::Common::Central::Server.new(services: services, accounts: accounts, data: Dir.mktmpdir)
    @server.services['/hunt'].instance_variable_set(:@book, book)
    book.trails.each_value.with_index { |trail, i| play(trail, accounts.register("Player#{i}", 'secret1')) }
  end

  private

  def play(trail, account)
    badges = Rubbs::Common::Central::Proxy.local(Rubbs::Common::Badges::Service, @server, aud: 'ttg-gate-bbs')
    hunt   = Rubbs::Common::Central::Proxy.local(Hunt::Service, @server, aud: 'ttg-gate-bbs')
    actor  = Rubbs::Common::Central::Actor.new(id: account.id, name: account.name)
    hunt.state(actor, hunt: trail.slug)
    trail.steps.each do |step|
      step.parts.each { |part| solve(badges, hunt, actor, trail, part) }
    end
    assert hunt.state(actor, hunt: trail.slug)['finish'], "#{trail.slug} could not be played home"
  end

  def solve(badges, hunt, actor, trail, part)
    case part
    when Hunt::Find
      fields = part.filter.transform_values { |v| Array(v).first }
      badges.record(actor, event: part.event, fields: fields, board: part.board)
    when Hunt::Answer
      @server.services['/hunt'].engine.instance_variable_get(:@db)[:hunt_attempts].delete
      assert_equal 'right', hunt.answer(actor, hunt: trail.slug, text: Array(part.value).first)['result']
    end
  end
end
