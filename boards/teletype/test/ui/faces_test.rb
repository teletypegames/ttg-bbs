# frozen_string_literal: true

require_relative '../test_helper'
require 'bbs/test'
require 'ttg/common'
require_relative '../../lib/ui/logo'
require_relative '../../lib/ui/arts'
require_relative '../../lib/ui/login'
require_relative '../../lib/ui/modern'
require_relative '../../lib/ui/petscii'

# Both faces on a board without the network: every window of the desktop
# opens and draws, a C64 call goes from the logon to the goodbye, and the
# entrance lets callers in on the accounts of the network.
class FacesTest < Minitest::Test
  include AccountsCase

  # What UI::Login is given of a call.
  Runner = Struct.new(:session, :context)
  # The site of a board without the network: no team, no events.
  class Offline
    def members = []
    def events = []
  end

  def setup
    @dir = Dir.mktmpdir('teletype-faces')
    BBS.config.env_prefix = 'TELETYPE_BBS_'
    ENV['TELETYPE_BBS_DB'] = File.join(@dir, 'teletype.sqlite3')
    @bbs = TeletypeBBS.new
    site = SiteService.new(Offline.new)
    @bbs.define_singleton_method(:site) { site }
    BBS.config.board = @bbs
    @context = { session_id: 's1', call_started: Time.now }
    @kali = BBS::Auth::Identity.guest('Kali')
    @bbs.start_call('s1', @kali, listed: true)
  end

  def teardown
    ENV.delete('TELETYPE_BBS_DB')
    BBS.config.board = nil
    FileUtils.rm_rf(@dir)
    super
  end

  WINDOWS = {
    system_info:   {},
    messages:      {},
    oneliners:     {},
    voting:        {},
    mail:          {},
    chat:          {},
    irc:           {},
    online_users:  {},
    last_callers:  {},
    user_list:     {},
    hall_of_fame:  {},
    register:      {},
    profile:       {},
    my_stats:      {},
    sysop_console: {},
    doors:         {},
    compose_mail:  { to: 'Sysop', subject: '', on_sent: nil },
    master:        { replies: Queue.new, question: nil }
  }.freeze

  def test_every_window_of_the_desktop_opens_and_draws
    session = BBS::Test::Session.new(identity: @kali)
    app = UI::Modern::APP.build(session: session, session_id: 's1', context: @context)
    WINDOWS.each do |name, extras|
      window = app.show(name, **extras)
      app.send(:render_screen)
      assert_equal name, window.id
      app.close_window(window)
    end
    app.show(:compose_message, message_board: @bbs.boards.boards.first)
    app.send(:render_screen)
  end

  def test_a_window_title_wears_its_section
    app = UI::Modern::APP.build(session: BBS::Test::Session.new(identity: @kali), session_id: 's1', context: @context)
    window = app.show(:messages)
    assert_equal '✉ Message Boards', window.title
    assert_equal UI::Modern::Accent::STYLES[:messages][:window_border], window.accent[:window_border]
  end

  def test_a_c64_call_runs_from_the_logon_to_the_goodbye
    identity = BBS::Auth::Identity.guest('KALI')
    session = BBS::Test::Session.new(keys: [:enter, 'y', :enter, 'q', 'y'], petscii: true, identity: identity)
    UI::Petscii.new(session, @context, @bbs).run
    assert_match(/thanks for calling, kali/i, session.output.scrub)
  end

  # The caller of +session+ through the modern entrance: UI::Login's answer.
  def enter(session)
    session.define_singleton_method(:naws_reported?) { true }
    UI::Login.call(Runner.new(session, { session_id: 's2' }), @bbs, UI::Modern::Clubhouse::Entrance.new(session, @bbs))
  end

  def typed(*lines) = lines.flat_map { |line| [*line.chars, :enter] }

  def test_a_caller_signed_in_at_the_gate_is_not_asked
    identity = account('Tasi', :sysop).with(source: :token)
    session = BBS::Test::Session.new(identity: identity)
    assert_nil enter(session)
    refute_includes session.output, 'Name (blank'
    assert_equal 'Tasi', @bbs.online.node('s2').name
    assert @bbs.online.node('s2').sysop
  end

  def test_an_account_logs_in_with_its_password
    account('Ada', password: 'secret-1')
    session = BBS::Test::Session.new(keys: typed('ada', 'secret-1'))
    assert_nil enter(session)
    assert session.identity.signed_in?
    assert_equal 'Ada', session.identity.name
  end

  def test_three_wrong_passwords_end_the_call
    account('Ada', password: 'secret-1')
    @bbs.members.instance_variable_set(:@pause, ->(_) {})
    session = BBS::Test::Session.new(keys: typed('Ada', 'x', 'y', 'z'))
    assert_equal :halt, enter(session)
    assert session.identity.guest?
    assert_includes session.output, 'Ada is a registered name.'
    assert_nil @bbs.online.node('s2')
  end

  def test_an_unknown_name_comes_in_as_a_guest
    accounts
    session = BBS::Test::Session.new(keys: typed('Zed'))
    assert_nil enter(session)
    assert session.identity.guest?
    assert_equal 'Zed', session.identity.name
    refute @bbs.online.node('s2').sysop
  end

  def test_the_sysop_items_are_for_the_sysop_role_only
    member = UI::Modern::APP.build(
      session:    BBS::Test::Session.new(identity: account('Kali')),
      session_id: 's1',
      context:    @context
    )
    refute member.sysop?
    sysop = UI::Modern::APP.build(
      session:    BBS::Test::Session.new(identity: account('Tasi', :sysop)),
      session_id: 's1',
      context:    @context
    )
    assert sysop.sysop?
    c64 = UI::Petscii.new(BBS::Test::Session.new(petscii: true, identity: account('Ada', :sysop)), @context, @bbs)
    assert c64.sysop?
  end
end
