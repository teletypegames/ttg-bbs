# frozen_string_literal: true

require 'test_helper'
require 'bbs/test'
require_relative '../lib/ui/petscii'

# The C64 face on a line without a socket: the page tree, the private pages
# for the wiki-supervisor role (the accounts of BBS::Test.accounts) and the
# refresh.
class PetsciiFaceTest < Minitest::Test
  Board = Struct.new(:wiki) do
    def services = { wiki: wiki }
  end

  # The wiki service without the wiki: two pages, a refresh answering +refresh+.
  class Wiki
    attr_reader :pages

    def initialize(refresh)
      @refresh = refresh
      @pages   = [page('/', 'Home'), page('/dos', 'DOS'), page('/dos/gmenu', 'GMENU', private: true)]
    end

    def refresh(_caller) = @refresh

    def page_markdown(page) = "# #{page.title}\n\nText of #{page.route}."

    private

    def page(route, title, private: false)
      PageModel.new(route: route, title: title, updated_at: '2026-11-01', tags: [], private: private)
    end
  end

  def teardown = BBS.config.auth = nil

  # The accounts of the network for the test, the board's login on them.
  def accounts
    @accounts ||= BBS::Test.accounts(roles: %w[member]).tap do |directory|
      BBS.config.auth = BBS::Auth::Setup.new(directory: directory, login: :menu, guests: true)
    end
  end

  def account(name, role: nil)
    accounts.register(name, 'secret-pass')
    accounts.grant(name, role) if role
    accounts.find(name)
  end

  def call(*keys, refresh: :refreshed, identity: nil)
    session = BBS::Test::Session.new(keys: [:enter, *keys], petscii: true, identity: identity)
    UI::Petscii.new(session, {}, Board.new(Wiki.new(refresh))).run
    BBS::FrameBuffer.plain(session.output).gsub(/\s+/, ' ')
  end

  # Down to DOS, then its second line, GMENU (private), and back up: locked,
  # then as a supervisor reads it.
  OPEN_PRIVATE = ['2', :enter, '2', :enter, ' ', 'q', 'q'].freeze
  READ_PRIVATE = ['2', :enter, '2', :enter, 'q', 'q', 'q'].freeze

  def test_the_top_level_lists_the_pages_with_a_mark_for_those_with_pages_under_them
    screen = call('q')
    assert_includes screen, 'ttg wiki bbs'
    assert_match(/DOS >/, screen)
    assert_includes screen, '3 pages'
    assert_includes screen, 'profile'
  end

  def test_a_private_page_stays_locked
    screen = call(*OPEN_PRIVATE)
    assert_includes screen, 'This page is private'
    refute_includes screen, 'Text of /dos/gmenu.'
  end

  def test_a_supervisor_reads_a_private_page
    screen = call(*READ_PRIVATE, identity: account('tasi', role: 'wiki-supervisor'))
    assert_includes screen, 'Text of /dos/gmenu.'
    assert_includes screen, 'profile'
  end

  def test_an_account_without_the_role_reads_no_private_page
    screen = call(*OPEN_PRIVATE, identity: account('reader'))
    assert_includes screen, 'reader is not a supervisor'
    refute_includes screen, 'Text of /dos/gmenu.'
  end

  def test_a_supervisor_logs_in_from_the_top_level
    account('tasi', role: 'wiki-supervisor')
    screen = call('p', 'l', *'tasi'.chars, :enter, *'secret-pass'.chars, :enter, ' ', 'b', *READ_PRIVATE)
    assert_includes screen, 'Welcome, tasi.'
    assert_includes screen, 'Text of /dos/gmenu.'
  end

  def test_logging_in_without_the_role_is_told
    account('reader')
    screen = call('p', 'l', *'reader'.chars, :enter, *'secret-pass'.chars, :enter, ' ', 'b', ' ', 'q')
    assert_includes screen, 'reader is not a supervisor'
  end

  def test_without_a_login_on_the_board_it_says_so
    assert_includes call('p', ' ', 'q'), 'Nobody logs in on this board.'
  end

  def test_a_refresh_too_soon_is_refused
    assert_includes call('r', ' ', 'q', refresh: :limited), 'The index was just refreshed.'
  end
end
