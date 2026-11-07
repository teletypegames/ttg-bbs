# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/ui/petscii'

# The Today tab (Herald): the calendar, the moon, the cache and its sources,
# the page on both faces. No request leaves the test: the sources are fakes.
class HeraldTest < Minitest::Test
  # A source of the Service that answers +payload+ or raises it.
  class FakeSource < Herald::Sources::Source
    KEY   = 'quakes'
    EVERY = 1800
    STALE = 6 * 3600

    attr_reader :calls

    def initialize(payload)
      super()
      @payload = payload
      @calls = 0
    end

    def fetch(_now)
      @calls += 1
      raise @payload if @payload.is_a?(Exception)

      @payload
    end
  end

  NOON = Time.utc(2026, 11, 7, 11)

  def store
    Rubbs::Test.database(HERALD_MIGRATIONS, name: :herald)
    Herald::Store.new
  end

  def calendar = Herald::Calendar.new

  def test_the_name_days_and_the_leap_day
    assert_equal %w[Csenger Rezső Ernő], calendar.day(NOON).namedays
    assert_equal %w[Mátyás Jázmin], calendar.namedays(Date.new(2027, 2, 24))
    assert_empty calendar.namedays(Date.new(2028, 2, 24))
    assert_equal %w[Mátyás Jázmin], calendar.namedays(Date.new(2028, 2, 25))
    refute_empty calendar.namedays(Date.new(2028, 2, 29))
  end

  def test_easter_and_the_holidays
    assert_equal Date.new(2026, 4, 5), Herald::Calendar.easter(2026)
    assert_equal Date.new(2027, 3, 28), Herald::Calendar.easter(2027)
    assert_equal ['Easter Monday'], calendar.holidays(Date.new(2027, 3, 29)).map(&:name)
    assert_equal ['Whit Monday'], calendar.holidays(Date.new(2026, 5, 25)).map(&:name)
    national = calendar.holidays(Date.new(2026, 3, 15)).first
    assert national.public
    refute calendar.holidays(Date.new(2026, 10, 31)).first.public
  end

  def test_the_day_is_budapests
    day = calendar.day(Time.utc(2026, 11, 7, 23, 30))
    assert_equal Date.new(2026, 11, 8), day.date
    assert_equal 6, calendar.day(NOON).sunrise.hour
    assert_in_delta 584, calendar.day(NOON).daylight, 10
  end

  def test_the_moon
    full = Herald::Moon.at(Time.utc(2026, 11, 24, 15))
    assert_equal 'full moon', full.name
    assert_operator full.percent, :>=, 97
    assert_equal 'new moon', Herald::Moon.at(Time.utc(2026, 11, 9, 8)).name
  end

  def test_a_source_is_fetched_when_due_and_a_failure_keeps_the_old
    s = store
    source = FakeSource.new({ 'quakes' => [{ 'mag' => 5.1, 'place' => 'Somewhere', 'time' => NOON.to_i - 3600 }] })
    service = Herald::Service.new(store: s, sources: [source])
    assert_equal ['quakes'], service.refresh(NOON)
    assert_empty service.refresh(NOON + 60)
    assert_equal 1, source.calls

    failing = FakeSource.new(Rubbs::Common::Web::HTTP::Error.new('down'))
    later = Herald::Service.new(store: s, sources: [failing])
    capture_io { assert_empty later.refresh(NOON + 3600) }
    assert_equal 5.1, later.edition(at: NOON + 3600).quakes.first.mag
    assert_empty later.edition(at: NOON + (7 * 3600)).quakes
  end

  def test_on_this_day_is_fetched_again_on_a_new_day
    source = Herald::Sources::OnThisDay.new
    entry = Herald::Store::Entry.new(payload: { 'stamp' => '11-07', 'events' => [] }, fetched_at: NOON.to_i)
    refute source.due?(entry, NOON + 3600)
    assert source.due?(entry, Time.utc(2026, 11, 7, 23, 30))
    refute source.fresh?(entry, Time.utc(2026, 11, 7, 23, 30))
  end

  def edition
    s = store
    s.put(
      'weather',
      {
        'hu' => {
          'place' => 'Budapest',
          'temp'  => 9.2,
          'code'  => 2,
          'wind'  => 5,
          'days'  => [[3, 10.1, 3.0], [1, 10.4, 1.9]]
        },
        'de' => { 'place' => 'Berlin', 'temp' => 4, 'code' => 0, 'wind' => 8, 'days' => [] }
      },
      at: NOON.to_i
    )
    s.put('rates', { 'date' => '2026-11-06', 'huf' => { 'EUR' => 363.9, 'USD' => 325.93 } }, at: NOON.to_i)
    s.put(
      'on_this_day',
      { 'stamp' => '11-07', 'events' => [{ 'year' => 1996, 'text' => 'Mars Global Surveyor launched.' }] },
      at: NOON.to_i
    )
    network = Herald::Network.new(
      callers:      2,
      boards:       14,
      walls:        [{ 'name' => 'Kati', 'text' => 'Hello!' }],
      online:       400,
      fresh:        3,
      board_of_day: nil
    )
    Herald::Service.new(store: s).edition(country: 'de', network: network, at: NOON)
  end

  def test_the_edition
    e = edition
    assert_equal %w[Budapest Berlin], e.weather.map(&:place)
    assert_equal 'partly cloudy', e.weather.first.words
    assert_equal 'overcast', e.weather.first.today.words
    assert_equal 'Sat 7 Nov · Name day Csenger, Rezső · Budapest 9°C partly cloudy', e.summary
    assert_equal 1996, e.events.first.year
    assert_empty e.quakes
  end

  def test_the_modern_page
    page = edition
    line = Rubbs::Test::Session.new(keys: %w[t q])
    bbs = Struct.new(:directory, :browse, :dials, :accounts) { define_method(:today) { |**| page } }
    boards = BoardRepository.new(File.join(Herald::ROOT, 'config/boards.yml'), host: 'localhost', public_host: 'example.org').all
    assert_nil UI::Modern::Gate.new(line, bbs.new(Struct.new(:boards).new(boards), nil, nil, nil)).run
    out = line.output
    assert_includes out, 'Name day Csenger, Rezső'
    assert_includes out, 'SATURDAY, 7 NOVEMBER 2026'
    assert_includes out, 'ON THIS DAY'
    assert_includes out, 'Mars Global Surveyor launched.'
    assert_includes out, 'EUR 363.90'
    assert_includes out, '2 on the gate'
    assert_includes out, 'Hello!'
    refute_includes out, 'Ours today'
  end

  def test_the_c64_pages
    view = UI::Petscii::Views::TodayView.new(edition, on_open: ->(_) {})
    texts = 4.times.map do |i|
      view.handle('+') if i.positive?
      canvas = UI::Petscii::Canvas.new(charset: :lower)
      view.draw(canvas)
      canvas.to_s
    end
    assert_includes texts[0], 'Saturday 7 November 2026'
    assert_includes texts[0], 'Csenger, Rezso, Erno'
    assert_includes texts[0], 'Budapest 9C partly cloudy'
    assert_includes texts[1], 'EUR 363.90'
    assert_includes texts[2], '1996 Mars Global Surveyor launched.'
    assert_includes texts[3], '2 on the gate now'
    texts.each { |t| assert(t.lines.all? { |l| l.chomp.length <= 40 }) }
  end
end
