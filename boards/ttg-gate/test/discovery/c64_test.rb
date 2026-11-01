# frozen_string_literal: true

require_relative 'test_helper'
require 'bbs'
require_relative '../../lib/ui/petscii'

module Discovery
  class C64Test < Minitest::Test
    Canvas = BBS::Petscii::Canvas

    def listing(name, state, country: 'us', tags: %w[petscii])
      ListingModel.new(id: name.hash, host: "#{name.downcase}.example.org", port: 64, name: name, state: state,
                       software: 'Synchronet', country: country, last_success_at: 1_000, first_probe_at: 1,
                       first_seen_at: 0, state_since: nil, tags: tags, optout: nil)
    end

    def board(items, **)
      UI::Petscii::DiscoveryBoard.new(items, title: 'PETSCII BOARDS', random: Random.new(3),
                                                                  now: -> { 1_000 + (3 * 86_400) }, **)
    end

    def screen(bytes) = Canvas.new.feed(bytes)

    def test_a_node_has_the_state_mark_instead_of_the_colour_block
      states = %w[online flaky down dead unknown]
      canvas = screen(board(states.map { |s| listing("Board #{s}", s) }).frame)
      marks = states.each_index.map { |i| canvas.cell(UI::Petscii::Switchboard::FRAME_TOP + 1 + i, 8) }
      assert_equal [0xd1, 0xd1, 0xd6, 0xdb, '?'.ord], marks.map(&:code)
      assert_equal [Canvas::LIGHT_GREEN, Canvas::YELLOW, Canvas::RED, Canvas::GREY, Canvas::LIGHT_GREY], marks.map(&:color)
      text = canvas.to_s.lines
      assert_includes text[UI::Petscii::Switchboard::FRAME_TOP + 2], 'BOARD FLAKY'
      assert_includes text[UI::Petscii::Switchboard::FRAME_TOP + 2], ' US '
      assert_includes text[UI::Petscii::Switchboard::LINK_ROW], 'STATE ONLINE'
      assert_includes text[UI::Petscii::Switchboard::FRAME_TOP], 'PETSCII BOARDS'
    end

    def test_eight_a_page_and_the_moves_send_patches_not_frames
      b = board(Array.new(11) { |i| listing("Board #{i}", 'online') })
      frame = b.frame
      assert_operator frame.bytesize, :<, 1600
      assert_equal 2, b.pages
      patch = b.move(1)
      assert_operator patch.bytesize, :<, 360
      refute_includes patch.bytes, Canvas::CLEAR
      assert_operator b.rain.bytesize, :<, 260
    end

    def test_the_status_of_a_down_board_and_menu_entries
      b = board([listing('Gone', 'down')])
      assert_includes screen(b.frame).to_s, 'DOWN FOR 3 DAYS'
      entry = UI::Petscii::DiscoveryBoard::Entry.new(name: 'Graveyard', right: 4, about: ['EVERY DEAD BOARD'], action: nil)
      text = screen(board([entry], help: :home).frame).to_s
      assert_includes text, '> GRAVEYARD'
      assert_includes text, 'EVERY DEAD BOARD'
      assert_includes text, 'G OWN'
    end

    def test_the_board_screen_shows_the_strip_and_only_petscii_banners
      page = BoardPageModel.new(listing: listing('Pub', 'online'),
                                board: { 'name' => 'Pub', 'provenance' => '{}', 'sysop' => 'Runstop' },
                                state: { 'last_success_at' => 1_000, 'banner' => "\x93HI".b, 'encoding' => 'petscii' },
                                sources: [], probes: [{ 'at' => 1_000, 'result' => 'ok' }])
      shown = UI::Petscii::BoardScreen.new(page, now: 1_000)
      text = screen(shown.frame).to_s
      assert_includes text, 'B SHOWS IT'
      assert_includes text, 'SYSOP    RUNSTOP'
      assert shown.banner?
      ansi = page.with(state: page.state.merge('encoding' => 'ansi'))
      refute UI::Petscii::BoardScreen.new(ansi, now: 1_000).banner?
      assert_includes screen(UI::Petscii::BoardScreen.new(ansi, now: 1_000).frame).to_s, 'ANSI: MODERN FACE ONLY'
    end
  end
end
