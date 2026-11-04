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
# opens and draws, and a C64 call goes from the logon to the goodbye.
class FacesTest < Minitest::Test
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
    @context = { session_id: 's1', username: 'Kali', authenticated: false, call_started: Time.now }
    @bbs.start_call('s1', 'Kali', listed: true)
  end

  def teardown
    ENV.delete('TELETYPE_BBS_DB')
    BBS.config.board = nil
    FileUtils.rm_rf(@dir)
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
    session = BBS::Test::Session.new
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
    app = UI::Modern::APP.build(session: BBS::Test::Session.new, session_id: 's1', context: @context)
    window = app.show(:messages)
    assert_equal '✉ Message Boards', window.title
    assert_equal UI::Modern::Accent::STYLES[:messages][:window_border], window.accent[:window_border]
  end

  def test_a_c64_call_runs_from_the_logon_to_the_goodbye
    session = BBS::Test::Session.new(keys: [:enter, 'y', :enter, 'q', 'y'], petscii: true)
    @context[:username] = 'KALI'
    UI::Petscii.new(session, @context, @bbs).run
    assert_match(/thanks for calling, kali/i, session.output.scrub)
  end
end
