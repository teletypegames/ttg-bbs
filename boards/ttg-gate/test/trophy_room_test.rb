# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/ui/petscii'

# The Trophy Room: its numbers from Grafana and the catalog (fakes, no
# request leaves the test), the Room, and the tab on both faces; on a C64
# one screen whose 40th column stays empty, the tabs and P to reach it.
class TrophyRoomTest < Minitest::Test
  Canvas = Rubbs::Petscii::Canvas

  # Grafana's answers by data source.
  class FakeGrafana
    def initialize(fail: [], configured: true)
      @fail = fail
      @configured = configured
    end

    def configured? = @configured

    def rows(uid, sql)
      raise Trophies::Grafana::Error, 'down' if @fail.include?(uid)

      case uid
      when Trophies::Queries::DOWNLOADS
        sql.include?('LIMIT 5') ? [['Ultimate Commander', 'c64', 171], ['Blessing of Ra', 'c64', 135]] : [[694, 129]]
      when Trophies::Queries::GITEA then [[3935, 71]]
      when Trophies::Queries::AUTHENTIK then [['Teletypers', 8], ['Jelölt', 3]]
      end
    end

    def value(_uid, expr) = expr.include?('success') ? 2646.0 : 3009.0
  end

  # The Source with the catalog's answer at hand.
  class Source < Trophies::Source
    FACETS_ANSWER = {
      'total'      => 36,
      'statuses'   => { 'released' => 21 },
      'platforms'  => { 'c64' => 11, 'dos' => 4 },
      'categories' => { 'game' => 21 }
    }.freeze

    def get_json(_url) = FACETS_ANSWER
  end

  NOW = Time.utc(2026, 11, 26, 12)

  def store
    Rubbs::Test.database(HERALD_MIGRATIONS, name: :herald)
    Herald::Store.new
  end

  def payload(grafana = FakeGrafana.new, store: nil)
    Source.new(grafana: grafana, catalog: 'https://example.org', store: store).fetch(NOW)
  end

  def room(at = Time.now.to_i - 720) = Trophies::Room.of(payload, boards: 16, accounts: 1234, updated_at: at)

  def test_the_numbers_have_their_thousands_apart
    assert_equal '5 761', Trophies.number(5761)
    assert_equal '1 234 567', Trophies.number(1_234_567)
    assert_equal '21', Trophies.number(21)
    assert_equal '-', Trophies.number(nil)
  end

  def test_the_source_fetches_every_part
    p = payload
    assert_equal [{ 'title' => 'Ultimate Commander', 'engine' => 'c64', 'downloads' => 171 },
                  { 'title' => 'Blessing of Ra', 'engine' => 'c64', 'downloads' => 135 }],
                 p['top']
    assert_equal({ 'count' => 694, 'visitors' => 129 }, p['downloads'])
    assert_equal({ 'count' => 3935, 'repos' => 71 }, p['commits'])
    assert_equal({ 'members' => 8, 'candidates' => 3 }, p['team'])
    assert_equal({ 'runs' => 3009, 'green' => 0.879 }, p['ci'])
    assert_equal({ 'released' => 21, 'titles' => 36, 'platforms' => 2, 'categories' => 1 }, p['catalog'])
  end

  def test_a_part_that_fails_keeps_what_it_had
    s = store
    s.put(Trophies::Source::KEY, payload, at: NOW.to_i - 3600)
    p = nil
    capture_io { p = payload(FakeGrafana.new(fail: [Trophies::Queries::GITEA]), store: s) }
    assert_equal({ 'count' => 3935, 'repos' => 71 }, p['commits'])
    capture_io { p = payload(FakeGrafana.new(fail: [Trophies::Queries::GITEA])) }
    assert_nil p['commits']
    assert_equal 694, p.dig('downloads', 'count')
  end

  def test_without_a_token_only_the_catalog_is_asked
    p = payload(FakeGrafana.new(configured: false))
    assert_nil p['top']
    assert_equal 21, p.dig('catalog', 'released')
  end

  def test_grafana_turns_a_frame_into_rows
    body = { 'results' => { 'A' => { 'frames' => [{ 'data' => { 'values' => [%w[a b], [1, 2]] } }] } } }
    http = Object.new
    http.define_singleton_method(:answer) { body }
    def http.post(url, headers:, **)
      raise 'wrong' unless url == 'http://grafana:3000/api/ds/query' && headers['Authorization'] == 'Bearer t'

      Struct.new(:status, :body).new(200, JSON.generate(answer))
    end
    grafana = Trophies::Grafana.new(url: 'http://grafana:3000/', token: 't', http: http)
    assert_equal [['a', 1], ['b', 2]], grafana.rows('uid', 'SELECT 1')
    refute Trophies::Grafana.new(url: 'x', token: '').configured?
  end

  def test_the_room
    r = room
    assert r.ready?
    assert_equal 5, r.core
    assert_equal 88, r.green_percent
    assert_equal 171, r.most
    refute Trophies::Room.of(nil, boards: 16, accounts: 3, updated_at: nil).ready?
  end

  def c64(view)
    canvas = Canvas.new(charset: :lower)
    view.draw(canvas)
    canvas
  end

  def test_the_c64_screen
    text = c64(UI::Petscii::Views::TrophyView.new(room)).to_s.lines.map(&:chomp)
    assert_equal ' TROPHY ROOM', text[3][0, 12]
    assert text[3].end_with?('all time')
    assert_equal ' MOST DOWNLOADED', text[5]
    assert_equal ' 1 Ultimate Command c64', text[6][0, 23]
    assert text[6].end_with?('171')
    assert_equal 38, text[6].length
    assert_match(/\A 694 downloads +129 visitors\z/, text[11])
    assert_equal '     21  released of 36 titles', text[14]
    assert_equal '  3 935  commits, 71 public repos', text[16]
    assert_equal '     16  BBS boards, 1 234 accounts', text[17]
    assert_equal '  3 009  CI runs, 88% green', text[18]
    assert_equal ' THE TEAM', text[20]
    assert_equal '      5  members, 3 candidates', text[21]
    assert_equal ' Updated 12m ago  teletypegames.org', text[23]
  end

  def test_the_c64_screen_never_prints_the_40th_column
    canvas = c64(UI::Petscii::Views::TrophyView.new(room))
    25.times { |row| refute canvas.cell(row, 39).visible?, "row #{row}" }
    long = Trophies::Room.of(
      payload.merge(
        'top'       => [{ 'title' => 'A very long title of a game', 'engine' => 'ebitengine', 'downloads' => 123_456 }],
        'downloads' => { 'count' => 9_999_999, 'visitors' => 8_888_888 }
      ),
      boards:     99_999,
      accounts:   999_999,
      updated_at: NOW.to_i
    )
    canvas = c64(UI::Petscii::Views::TrophyView.new(long))
    25.times { |row| refute canvas.cell(row, 39).visible?, "row #{row}" }
    assert_includes canvas.to_s, 'ebit'
  end

  def test_the_c64_screen_before_the_numbers_came
    text = c64(UI::Petscii::Views::TrophyView.new(nil)).to_s
    assert_includes text, 'The trophies are being polished.'
  end

  def gate(keys = [])
    @line = Rubbs::Test::Session.new(keys: keys, petscii: true)
    UI::Petscii::Gate.new(@line, boards: [], browse: nil, dials: nil, trophies: -> { room }).tap(&:start)
  end

  def shown = @line.writes.each_with_object([Canvas.new]) { |w, all| all << all.last.dup.feed(w) }.last

  def test_the_c64_bar_has_five_tabs_in_39_cells
    gate
    bar = shown.to_s.lines.first.chomp
    assert_equal ' TTG  OWN  GLOBAL  TODAY  TROPHY  YOU', bar.rstrip
    assert_operator bar.rstrip.length, :<=, 39
    assert_equal UI::Petscii::Chrome::KIT.colors[:key], shown.cell(0, 29).color
  end

  def test_p_opens_the_trophy_room_and_the_tabs_go_round
    g = gate
    g.press('p')
    assert_equal :trophy, g.tab
    assert_includes shown.to_s, 'MOST DOWNLOADED'
    assert_includes shown.to_s, 'all time'
    g.press(:up)
    assert_equal :bar, g.focus
    g.press(:right)
    assert_equal :account, g.tab
    g.press(:left)
    assert_equal :trophy, g.tab
    g.press(:left)
    assert_equal :today, g.tab
    g.press(:right)
    assert_equal :trophy, g.tab
    assert_equal :bar, g.focus
    g.press(:down)
    assert_equal :main, g.focus
    g.press('y')
    assert_equal :account, g.tab
    g.press('t')
    assert_equal :today, g.tab
    g.press('p')
    assert_equal :trophy, g.tab
    g.press('a')
    assert_equal :account, g.tab
  end

  def test_the_c64_help_names_the_trophy_room
    assert_includes c64(UI::Petscii::Views::TextView.help).to_s, 'P: Trophy Room  Y, A: You'
  end

  def test_the_modern_tab
    r = room
    line = Rubbs::Test::Session.new(keys: %w[p q])
    bbs = Struct.new(:directory, :browse, :dials, :accounts) { define_method(:trophies) { r } }
    boards = BoardRepository.new(File.join(Herald::ROOT, 'config/boards.yml'), host: 'localhost', public_host: 'example.org').all
    assert_nil UI::Modern::Gate.new(line, bbs.new(DirectoryService.new(Struct.new(:all).new(boards)), nil, nil, nil)).run
    out = line.output
    assert_includes out, 'TROPHY ROOM'
    assert_includes out, 'MOST DOWNLOADED'
    assert_includes out, 'Ultimate Commander'
    assert_includes out, '3 935'
    assert_includes out, 'commits in 71 public repos'
    assert_includes out, 'members · 3 candidates'
  end
end
