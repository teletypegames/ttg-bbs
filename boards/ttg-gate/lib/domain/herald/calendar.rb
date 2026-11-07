# frozen_string_literal: true

require 'date'
require 'yaml'

module Herald
  # What kind of day it is in Budapest: the date, the Hungarian name days,
  # the holidays (config/herald/holidays.yml, the Easter ones worked out),
  # sunrise and sunset (Rubbs::Common::Season) and the moon (Moon). Pure:
  # everything follows from the instant, so a test passes the one it wants.
  #
  #   Herald::Calendar.new.day(Time.utc(2026, 11, 7, 12))
  #   # => #<data Day date=2026-11-07, namedays=["Csenger", "Rezső", "Ernő"], …>
  class Calendar
    # A day: its +date+, +namedays+ (Strings), +holidays+ (Holiday each),
    # +sunrise+ and +sunset+ (local Times or +nil+) and the +moon+ (a
    # Moon::Phase).
    Day = Data.define(:date, :namedays, :holidays, :sunrise, :sunset, :moon) do
      # The length of the day in minutes, or +nil+.
      def daylight = sunrise && sunset ? ((sunset - sunrise) / 60).round : nil
    end

    # A holiday: its +name+ and whether it is a public holiday in Hungary.
    Holiday = Data.define(:name, :public)

    # [namedays] month => day => names (config/herald/namedays.yml)
    # [holidays] the +fixed+ and +easter+ days (config/herald/holidays.yml)
    def initialize(namedays: Herald.config('namedays'), holidays: Herald.config('holidays'))
      @namedays = namedays
      @fixed    = holidays.fetch('fixed', {})
      @easter   = holidays.fetch('easter', {}).transform_keys(&:to_i)
    end

    # The Day of +at+ (a Time) in Budapest.
    def day(at = Time.now)
      season = Rubbs::Common::Season.now(tz: ZONE, at: at)
      date   = season.time.to_date
      Day.new(
        date:     date,
        namedays: namedays(date),
        holidays: holidays(date),
        sunrise:  season.sunrise,
        sunset:   season.sunset,
        moon:     Moon.at(at)
      )
    end

    # The name days of +date+. In a leap year February 24 has none and the
    # names of February 24-28 come a day later.
    def namedays(date)
      month = date.month
      day = date.day
      if date.leap? && month == 2 && day >= 24
        return [] if day == 24

        day -= 1
      end
      Array(@namedays.dig(month, day))
    end

    # The holidays of +date+, the public ones first.
    def holidays(date)
      found = [@fixed[date.strftime('%m-%d')], @easter[(date - Calendar.easter(date.year)).to_i]].compact
      found.map { |h| Holiday.new(name: h.fetch('name'), public: h['public'] == true) }.sort_by { |h| h.public ? 0 : 1 }
    end

    # Easter Sunday of +year+ (the Gregorian computus, after Meeus).
    def self.easter(year)
      h, l = easter_terms(year)
      m = ((year % 19) + (11 * h) + (19 * l)) / 433
      month = (h + l - (7 * m) + 90) / 25
      Date.new(year, month, (h + l - (7 * m) + (33 * month) + 19) % 32)
    end

    # The epact-like +h+ and the weekday term +l+ of the computus for +year+.
    def self.easter_terms(year)
      b, c = year.divmod(100)
      d, e = b.divmod(4)
      h = ((19 * (year % 19)) + b - d - (((8 * b) + 13) / 25) + 15) % 30
      i, k = c.divmod(4)
      [h, (32 + (2 * e) + (2 * i) - h - k) % 7]
    end
  end
end
