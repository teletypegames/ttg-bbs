# frozen_string_literal: true

require_relative '../test_helper'
require 'rubbs/test'
require 'ttg/common'
require_relative '../../lib/ui/logo'
require_relative '../../lib/ui/arts'
require_relative '../../lib/ui/login'
require_relative '../../lib/ui/modern'
require_relative '../../lib/ui/petscii'

# Both faces on a board without the network: every window of the desktop
# opens and draws, a C64 call goes from the main menu to the goodbye, and a
# call the splash let in is put on the board.
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
    Rubbs.config.env_prefix = 'TELETYPE_BBS_'
    ENV['TELETYPE_BBS_DB'] = File.join(@dir, 'teletype.sqlite3')
    @bbs = TeletypeBBS.new
    site = SiteService.new(Offline.new)
    @bbs.define_singleton_method(:site) { site }
    Rubbs.config.board = @bbs
    @context = { session_id: 's1', call_started: Time.now }
    @kali = Rubbs::Common::Auth::Identity.guest('Kali')
    @bbs.start_call('s1', @kali, listed: true)
  end

  def teardown
    ENV.delete('TELETYPE_BBS_DB')
    Rubbs.config.board = nil
    FileUtils.rm_rf(@dir)
    super
  end

  WINDOWS = {
    system_info:   {},
    voting:        {},
    online_users:  {},
    last_callers:  {},
    user_list:     {},
    hall_of_fame:  {},
    register:      {},
    profile:       {},
    my_stats:      {},
    sysop_console: {},
    doors:         {},
    master:        { replies: Queue.new, question: nil }
  }.freeze

  def test_every_window_of_the_desktop_opens_and_draws
    session = Rubbs::Test::Session.new(identity: @kali)
    app = UI::Modern::APP.build(session: session, session_id: 's1', context: @context)
    WINDOWS.each do |name, extras|
      window = app.show(name, **extras)
      app.send(:render_screen)
      assert_equal name, window.id
      app.close_window(window)
    end
  end

  def test_the_town_map_and_the_trophies_draw
    session = Rubbs::Test::Session.new(identity: @kali, cols: 100, rows: 40)
    app = UI::Modern::APP.build(session: session, session_id: 's1', context: @context)
    %i[open_town_map open_trophies].each do |opener|
      app.send(opener)
      app.send(:render_screen)
    end
    assert_includes session.output, 'Town Map'
  end

  def test_a_window_title_wears_its_section
    app = UI::Modern::APP.build(session: Rubbs::Test::Session.new(identity: @kali), session_id: 's1', context: @context)
    window = app.show(:voting)
    assert_equal '✉ Voting Booth', window.title
    assert_equal UI::Modern::Accent::STYLES[:messages][:window_border], window.accent[:window_border]
  end

  def test_a_c64_call_runs_from_the_menu_to_the_goodbye
    identity = Rubbs::Common::Auth::Identity.guest('KALI')
    session = Rubbs::Test::Session.new(keys: ['y', :enter, 'q', 'y'], petscii: true, identity: identity)
    UI::Petscii.new(session, @context, @bbs).run
    assert_match(/thanks for calling, kali/i, session.output.scrub)
  end

  # The start of a call the splash let in: UI::Login's answer.
  def enter(session, listed: true)
    UI::Login.call(Runner.new(session, { session_id: 's2' }), @bbs, listed: listed)
  end

  def test_a_signed_in_caller_goes_on_the_node_list
    session = Rubbs::Test::Session.new(identity: account('Tasi', :sysop).with(source: :token))
    assert_nil enter(session)
    assert_equal 'Tasi', @bbs.online.node('s2').name
    assert @bbs.online.node('s2').sysop
    assert_empty session.output
  end

  def test_a_guest_comes_in_as_anonymous
    assert_nil enter(Rubbs::Test::Session.new(identity: Rubbs::Common::Auth::Identity.guest))
    assert_equal 'Anonymous', @bbs.online.node('s2').name
    refute @bbs.online.node('s2').sysop
  end

  def test_a_scanner_is_not_listed
    assert_nil enter(Rubbs::Test::Session.new(identity: Rubbs::Common::Auth::Identity.guest), listed: false)
    assert_nil @bbs.online.node('s2')
  end

  def test_stepping_through_a_door_marks_the_node
    door = @bbs.doors.first
    UI::Modern::APP.instance_variable_get(:@door_block).call(door, { session_id: 's1' })
    assert_equal 'Door: SERMO', @bbs.online.node('s1').activity
  end

  def test_the_sysop_items_are_for_the_sysop_role_only
    member = UI::Modern::APP.build(
      session:    Rubbs::Test::Session.new(identity: account('Kali')),
      session_id: 's1',
      context:    @context
    )
    refute member.sysop?
    sysop = UI::Modern::APP.build(
      session:    Rubbs::Test::Session.new(identity: account('Tasi', :sysop)),
      session_id: 's1',
      context:    @context
    )
    assert sysop.sysop?
    c64 = UI::Petscii.new(Rubbs::Test::Session.new(petscii: true, identity: account('Ada', :sysop)), @context, @bbs)
    assert c64.sysop?
  end
end
