# frozen_string_literal: true

require 'test_helper'

class TipServiceTest < Minitest::Test
  include TmpData

  # A catalog of two games.
  class Catalog
    GAMES = { 'Q1' => game('Q1', 'Zork'), 'Q2' => game('Q2', 'Elite') }.freeze

    def find(id) = GAMES[id]
  end

  def service(seeds: [], notifier: nil)
    @repository = TipRepository.new(BBS::SQLite.new(path('tips.sqlite3')))
    TipService.new(@repository, catalog: Catalog.new, seeds: seeds, notifier: notifier)
  end

  def zork = Catalog::GAMES['Q1']

  def test_a_tip_waits_for_an_admin
    tips = service
    assert_equal :ok, tips.submit(zork, text: 'POKE 53280,0', caller: '1.2.3.4')
    assert_empty tips.tips(zork)
    tips.approve(tips.pending.first.id)
    assert_equal ['POKE 53280,0'], tips.tips(zork).map(&:text)
  end

  def test_text_and_handle_are_one_clean_line
    tips = service
    tips.submit(zork, text: "line one\r\n\e[2Jline\u202e two", handle: "  ad\ea  #{'x' * 40}", caller: 'k')
    tip = tips.pending.first
    assert_equal ['line one [2Jline two', "ada #{'x' * 16}"], [tip.text, tip.handle]
  end

  def test_empty_and_too_long_tips_are_refused
    tips = service
    assert_equal :empty, tips.submit(zork, text: " \e ", caller: 'k')
    assert_equal :too_long, tips.submit(zork, text: 'x' * (TipService::MAX_TEXT + 1), caller: 'k')
  end

  def test_a_caller_waits_between_tips_whatever_the_session
    tips = service
    assert_equal :ok, tips.submit(zork, text: 'one', caller: '1.2.3.4')
    assert_equal :rate_limited, tips.submit(zork, text: 'two', caller: '1.2.3.4')
    assert_equal :ok, tips.submit(zork, text: 'two', caller: '5.6.7.8')
  end

  def test_the_whole_board_takes_board_max_an_hour
    tips = service
    results = (TipService::BOARD_MAX + 1).times.map { |n| tips.submit(zork, text: "tip #{n}", caller: "10.0.#{n}.1") }
    assert_equal [:ok] * TipService::BOARD_MAX, results.first(TipService::BOARD_MAX)
    assert_equal :rate_limited, results.last
  end

  def test_seeds_are_approved_once_and_games_with_tips_are_by_title
    seeds = [{ game_id: 'Q1', seed: 'a', handle: '', text: 'z' }, { game_id: 'Q2', seed: 'b', handle: '', text: 'e' }]
    service(seeds: seeds)
    tips = service(seeds: seeds)
    assert_equal %w[Elite Zork], tips.games_with_tips.map(&:title)
    assert_equal 1, tips.count(zork)
  end

  def test_the_admins_hear_of_a_new_tip
    heard = []
    service(notifier: ->(tip, game) { heard << [tip.text, game.title] }).submit(zork, text: 'hi', caller: 'k')
    assert_equal [%w[hi Zork]], heard
  end
end
