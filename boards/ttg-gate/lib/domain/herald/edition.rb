# frozen_string_literal: true

module Herald
  # The weather of a WMO code (Open-Meteo's +weather_code+) in a few words.
  WEATHER = {
    0  => 'clear sky',
    1  => 'mainly clear',
    2  => 'partly cloudy',
    3  => 'overcast',
    45 => 'fog',
    48 => 'rime fog',
    51 => 'light drizzle',
    53 => 'drizzle',
    55 => 'dense drizzle',
    56 => 'freezing drizzle',
    57 => 'freezing drizzle',
    61 => 'light rain',
    63 => 'rain',
    65 => 'heavy rain',
    66 => 'freezing rain',
    67 => 'freezing rain',
    71 => 'light snow',
    73 => 'snow',
    75 => 'heavy snow',
    77 => 'snow grains',
    80 => 'showers',
    81 => 'showers',
    82 => 'violent showers',
    85 => 'snow showers',
    86 => 'snow showers',
    95 => 'thunderstorm',
    96 => 'thunderstorm, hail',
    99 => 'thunderstorm, hail'
  }.freeze

  # The words of WMO code +code+.
  def self.weather(code) = WEATHER.fetch(code.to_i, 'weather unknown')

  # A day of a Forecast: its +words+, +high+ and +low+ (°C).
  DayForecast = Data.define(:words, :high, :low)

  # The weather of a place: its +place+, the temperature now (+temp+, °C),
  # the +words+ for now, the +wind+ (km/h), and +today+ and +tomorrow+,
  # DayForecast each (or +nil+).
  Forecast = Data.define(:place, :temp, :words, :wind, :today, :tomorrow) do
    # The Forecast of a weather payload's place, +nil+ for none.
    def self.of(data)
      return unless data

      today, tomorrow = Array(data['days']).map { |code, high, low| DayForecast.new(Herald.weather(code), high, low) }
      new(
        place:    data['place'],
        temp:     data['temp'],
        words:    Herald.weather(data['code']),
        wind:     data['wind'],
        today:    today,
        tomorrow: tomorrow
      )
    end
  end

  # The forint rates of a day: its +date+ (a String, YYYY-MM-DD) and +huf+,
  # currency => forints.
  Rates = Data.define(:date, :huf)

  # An event of the day in history: its +year+ and +text+.
  Event = Data.define(:year, :text)

  # An earthquake: its +mag+nitude, +place+ and +time+ (epoch seconds).
  Quake = Data.define(:mag, :place, :time)

  # The network now, as the gate sees it: the +callers+ on the gate, our own
  # +boards+, the newest +walls+ notes (Hashes of +name+, +text+), the
  # catalog's boards +online+ and +fresh+ this week, and the +board_of_day+
  # (a Discovery listing, or +nil+).
  Network = Data.define(:callers, :boards, :walls, :online, :fresh, :board_of_day)

  # The Today tab's page for one caller at one instant: the +day+ (a
  # Calendar::Day), the +weather+ (Forecasts: Budapest, then the caller's
  # capital), the +rates+, the +events+ of the day, the +quakes+ and the
  # +network+; each part +nil+ or empty when its source has nothing fresh.
  Edition = Data.define(:at, :day, :weather, :rates, :events, :quakes, :network) do
    # The day, the name days and the weather in one line, for a top line.
    def summary = [day.date.strftime('%a %-d %b'), *day_words, *weather_words].join(' · ')

    private

    def day_words
      names = day.namedays.first(2)
      [("Name day #{names.join(', ')}" if names.any?), day.holidays.first&.name].compact
    end

    def weather_words
      here = weather.first
      here ? ["#{here.place} #{here.temp.round}°C #{here.words}"] : []
    end
  end
end
