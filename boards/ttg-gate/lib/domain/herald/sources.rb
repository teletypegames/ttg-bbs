# frozen_string_literal: true

require 'json'
require 'rexml/document'
require 'uri'

module Herald
  # The web sources of the Today tab. Each answers its +key+ (the Store's
  # row), how often it is fetched (+every+, seconds), the +stamp+ of the
  # payload it wants now (a payload of another stamp, an earlier day's, is
  # fetched again at once) and #fetch, the payload: plain data JSON carries.
  # A failure raises; the Service logs it and the old payload stays.
  module Sources
    # The longest a request may take, in seconds.
    DEADLINE = 20

    # What every source shares.
    class Source
      # The Store row of the source.
      def key = self.class::KEY

      # Seconds between two fetches.
      def every = self.class::EVERY

      # The stamp a payload fetched +now+ carries; +nil+ when any will do.
      def stamp(_now) = nil

      # Whether +entry+ (a Store::Entry) may still be shown at +now+: not
      # older than the source's STALE seconds, and of today's stamp.
      def fresh?(entry, now)
        return false unless entry
        return false if stamp(now) && entry.payload['stamp'] != stamp(now)

        now.to_i - entry.fetched_at <= self.class::STALE
      end

      # Whether it is time to fetch again at +now+, +entry+ the last fetch.
      def due?(entry, now)
        return true unless entry
        return true if stamp(now) && entry.payload['stamp'] != stamp(now)

        now.to_i - entry.fetched_at >= every
      end

      private

      def get_json(url) = JSON.parse(get(url))

      def get(url)
        response = Rubbs::Common::Web::HTTP.get(url, deadline: DEADLINE)
        raise Rubbs::Common::Web::HTTP::Error, "#{key}: HTTP #{response.status}" unless response.ok?

        response.body.force_encoding(Encoding::UTF_8)
      end
    end

    # The weather now, today and tomorrow in Budapest and in the capitals of
    # config/herald/capitals.yml, from Open-Meteo (CC BY 4.0) in one request.
    # The payload: country => { place, temp, code, wind, days: [[code, max, min] × 2] }.
    class Weather < Source
      KEY   = 'weather'
      EVERY = 3600
      STALE = 6 * 3600
      URL   = 'https://api.open-meteo.com/v1/forecast'

      # [places] country => [name, latitude, longitude]
      def initialize(places: Herald.config('capitals'))
        super()
        @places = places
      end

      def fetch(_now = Time.now)
        answer = get_json("#{URL}?#{query}")
        answer = [answer] unless answer.is_a?(Array)
        @places.keys.zip(answer).to_h { |country, at| [country, place(@places[country].first, at)] }
      end

      private

      def query
        URI.encode_www_form(
          latitude:      @places.values.map { |p| p[1] }.join(','),
          longitude:     @places.values.map { |p| p[2] }.join(','),
          current:       'temperature_2m,weather_code,wind_speed_10m',
          daily:         'weather_code,temperature_2m_max,temperature_2m_min',
          timezone:      'auto',
          forecast_days: 2
        )
      end

      def place(name, at)
        now = at.fetch('current')
        daily = at.fetch('daily')
        days = daily['time'].each_index.map do |i|
          [daily['weather_code'][i], daily['temperature_2m_max'][i], daily['temperature_2m_min'][i]]
        end
        {
          'place' => name,
          'temp'  => now['temperature_2m'],
          'code'  => now['weather_code'],
          'wind'  => now['wind_speed_10m'],
          'days'  => days
        }
      end
    end

    # The euro reference rates of the European Central Bank, turned into
    # forints: the payload is { date, huf: { EUR, USD, GBP, CHF => forints } }.
    class Rates < Source
      KEY   = 'rates'
      EVERY = 3600
      STALE = 4 * 86_400
      URL   = 'https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml'
      # The currencies shown, in order.
      CURRENCIES = %w[EUR USD GBP CHF].freeze

      def fetch(_now = Time.now)
        doc   = REXML::Document.new(get(URL))
        day   = REXML::XPath.first(doc, '//*[@time]') or raise Rubbs::Common::Web::HTTP::Error, 'rates: no day'
        euro  = REXML::XPath.match(day, '*[@currency]').to_h { |c| [c['currency'], Float(c['rate'])] }
        huf   = euro.fetch('HUF') { raise Rubbs::Common::Web::HTTP::Error, 'rates: no HUF' }
        { 'date' => day['time'], 'huf' => CURRENCIES.to_h { |c| [c, (c == 'EUR' ? huf : huf / euro.fetch(c)).round(2)] } }
      end
    end

    # What happened on this day, the selected events of the English
    # Wikipedia's feed (CC BY-SA): { day, events: [{ year, text }] }.
    class OnThisDay < Source
      KEY   = 'on_this_day'
      EVERY = 6 * 3600
      STALE = 86_400
      URL   = 'https://en.wikipedia.org/api/rest_v1/feed/onthisday/selected/%<month>02d/%<day>02d'
      # The most events kept.
      KEEP = 12

      def stamp(now) = Herald.local(now).strftime('%m-%d')

      def fetch(now = Time.now)
        local  = Herald.local(now)
        answer = get_json(format(URL, month: local.month, day: local.day))
        events = Array(answer['selected']).first(KEEP).map { |e| { 'year' => e['year'], 'text' => e['text'].to_s } }
        { 'stamp' => stamp(now), 'events' => events }
      end
    end

    # The earthquakes of magnitude 4.5 and over in the last day, from the
    # USGS (public domain): { quakes: [{ mag, place, time }] }, the biggest
    # first.
    class Quakes < Source
      KEY   = 'quakes'
      EVERY = 1800
      STALE = 6 * 3600
      URL   = 'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_day.geojson'
      # The most quakes kept.
      KEEP = 6

      def fetch(_now = Time.now)
        quakes = Array(get_json(URL)['features']).map do |f|
          p = f['properties']
          { 'mag' => p['mag'].to_f, 'place' => p['place'].to_s, 'time' => p['time'].to_i / 1000 }
        end
        { 'quakes' => quakes.sort_by { |q| -q['mag'] }.first(KEEP) }
      end
    end

    # Every source, in the order they are fetched.
    ALL = [Weather, Rates, OnThisDay, Quakes].freeze
  end
end
