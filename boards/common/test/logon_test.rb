# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'network_test'

# The sign-in notice: the day's bulletin once a day, the letters that came since the last time,
# and the feedback kept on the board while the Central is away.
class LogonTest < Minitest::Test
  include CentralHelper

  def setup
    super
    @server.stop
    @server = Rubbs::Common::Central::Server.new(
      services: [Rubbs::Common::Auth::Service, TTG::Feedback::Service, TTG::PrivateMessage::Service, TTG::Bulletin::Service],
      accounts: @accounts,
      data:     @data
    )
    Rubbs.config.central = Rubbs::Common::Central::Link.new(server: @server)
    TTG::Bulletin.source = ->(_at) { ['Fri 27 Nov · Name day Virgil', 'Siliconia BBS: Machine of the week'] }
    TTG::Logon.hint = nil
    TTG::Feedback::Outbox.dir = File.join(@data, 'outbox')
  end

  def teardown
    TTG::Bulletin.source = nil
    TTG::Feedback::Outbox.dir = nil
    super
  end

  def line(identity) = Rubbs::Test::Session.new(identity: identity).tap { |s| s.face = :modern }

  def write_to_ada(subject, from: @bob)
    TTG::PrivateMessage.mail.call(:write, actor(from), to: 'Ada', subject: subject, body: 'hello')
  end

  def test_the_new_letters_are_told_once
    assert_equal 0, TTG::PrivateMessage.news(line(@ada))
    write_to_ada('one')
    assert_equal 1, TTG::PrivateMessage.news(line(@ada))
    assert_equal 0, TTG::PrivateMessage.news(line(@ada))
    write_to_ada('two', from: @accounts.register('Cyd', 'secret3'))
    assert_equal 2, TTG::PrivateMessage.news(line(@ada))
  end

  def test_the_bulletin_comes_once_a_day_and_not_to_a_guest
    assert_equal 2, TTG::Bulletin.today(line(@ada)).size
    assert_empty TTG::Bulletin.today(line(@ada))
    assert_empty TTG::Bulletin.today(line(Rubbs::Common::Auth::Identity.guest))
  end

  def test_a_sign_in_leaves_one_notice_of_the_day_and_the_letters
    write_to_ada('one')
    TTG::Logon.hint = 'T: the whole day on the Today tab.'
    session = line(@ada)
    text = TTG::Logon.greet(session)
    assert_includes text, 'Name day Virgil'
    assert_includes text, 'the Today tab'
    assert_includes text, '1 unread letter: M in your profile'
    assert_equal ['Today on the network'], session.take_notices.map(&:title)
    assert_nil TTG::Logon.greet(line(@ada)), 'nothing new the second time'
  end

  def test_feedback_is_kept_while_the_central_is_away_and_sent_with_its_time
    kept = TTG::Feedback::Outbox.keep(guest('Joe'), { kind: 'bug', subject: 'x', body: 'it broke' }, at: Time.now - 120)
    assert File.exist?(kept)
    link = Rubbs.config.central
    Rubbs.config.central = nil
    assert_equal 0, TTG::Feedback::Outbox.deliver
    assert File.exist?(kept), 'kept while away'
    Rubbs.config.central = link
    assert_equal 1, TTG::Feedback::Outbox.deliver
    refute File.exist?(kept)
    row = @server.services['/feedback'].store.instance_variable_get(:@db)[:feedback].first
    assert_operator Time.now.utc - Time.iso8601(row[:created_at]), :>=, 100
  ensure
    TTG::Feedback::Outbox.instance_variable_get(:@worker)&.kill
  end
end

class NetworkLinksTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    File.write(File.join(@dir, 'boards.yml'), "commodex: { port: 2331 }\nsiliconia: { port: 2338 }\n")
    TTG::Network.settings_file = File.join(@dir, 'boards.yml')
  end

  def teardown
    TTG::Network.settings_file = nil
    FileUtils.rm_rf(@dir)
  end

  def test_the_links_of_a_machine_a_game_and_a_directory
    c64 = [['its games on Commodex BBS', 'commodex', nil],
           ['our Commodore 64 titles on WarpEngine BBS', 'warp-engine', 'directory:c64']]
    assert_equal c64, TTG::Network.machine_links('Q99775')
    assert_equal ['directory:plus4'], TTG::Network.machine_links('Q1115913').map(&:last)
    assert_empty TTG::Network.machine_links('Q1')
    assert_equal %w[machine:Q868568 machine:Q1115913], TTG::Network.directory_links('plus4').map(&:last)
    assert_equal(%w[siliconia warp-engine], TTG::Network.game_links.map { |l| l[1] })
  end

  def test_only_the_boards_with_a_port_are_reachable
    assert_equal 2331, TTG::Network.port('commodex')
    assert_nil TTG::Network.port('warp-engine')
    assert_equal(['commodex'], TTG::Network.reachable(TTG::Network.machine_links('Q99775')).map { |l| l[1] })
    assert_nil TTG::Network.visit(Rubbs::Test::Session.new, 'warp-engine', 'directory:c64')
  end

  def test_a_place_is_read_by_its_kind
    assert_equal 'Q99775', TTG::Network.place_of('machine:Q99775', 'machine')
    assert_nil TTG::Network.place_of('directory:c64', 'machine')
    assert_nil TTG::Network.place_of(nil, 'machine')
  end
end
