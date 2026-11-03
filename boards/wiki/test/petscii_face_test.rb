# frozen_string_literal: true

require 'test_helper'
require 'bbs/test'
require_relative '../lib/ui/petscii'

# The C64 face on a line without a socket: the page tree, the supervisor
# lock and the refresh.
class PetsciiFaceTest < Minitest::Test
  Board = Struct.new(:wiki, :supervisor) do
    def services = { wiki: wiki, supervisor: supervisor }
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

  def call(*keys, refresh: :refreshed, password: '')
    session = BBS::Test::Session.new(keys: [:enter, *keys], petscii: true)
    supervisor = SupervisorService.new(password)
    UI::Petscii.new(session, {}, Board.new(Wiki.new(refresh), supervisor)).run
    BBS::FrameBuffer.plain(session.output)
  end

  def test_the_top_level_lists_the_pages_with_a_mark_for_those_with_pages_under_them
    screen = call('q')
    assert_includes screen, 'ttg wiki bbs'
    assert_match(/DOS >/, screen)
    assert_includes screen, '3 pages'
  end

  def test_a_private_page_stays_locked
    screen = call('2', :enter, '2', :enter, ' ', 'q', 'q')
    assert_includes screen, 'Supervisor only.'
  end

  def test_without_a_password_the_supervisor_login_says_so
    assert_includes call('s', ' ', 'q'), 'No supervisor password configured.'
  end

  def test_a_refresh_too_soon_is_refused
    assert_includes call('r', ' ', 'q', refresh: :limited), 'The index was just refreshed.'
  end
end
