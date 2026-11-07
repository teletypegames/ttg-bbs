# frozen_string_literal: true

module Herald
  # The Today tab's work: #refresh fetches the sources that are due into the
  # Store (in the background, Rubbs.background), #edition makes a caller's
  # page from the Store and the Calendar, never from the web.
  class Service
    # The capital whose weather is always shown.
    HOME = 'hu'

    # [store]    a Store
    # [calendar] a Calendar
    # [sources]  the web sources (Sources::ALL made, by default)
    def initialize(store:, calendar: Calendar.new, sources: Sources::ALL.map(&:new))
      @store    = store
      @calendar = calendar
      @sources  = sources.to_h { |s| [s.key, s] }
    end

    # Fetches every source that is due at +now+; a failed one is logged and
    # keeps its old payload. Returns the keys fetched.
    def refresh(now = Time.now)
      @sources.values.filter_map do |source|
        next unless source.due?(@store.get(source.key), now)

        @store.put(source.key, source.fetch(now), at: now.to_i)
        source.key
      rescue StandardError => e
        Rubbs.log("herald #{source.key}", e, level: :warn)
        nil
      end
    end

    # The Edition at +at+ for a caller of +country+ (an ISO code, lower
    # case, or +nil+), with the +network+ (a Network, or +nil+).
    def edition(country: nil, network: nil, at: Time.now)
      Edition.new(
        at:      at,
        day:     @calendar.day(at),
        weather: weather(country, at),
        rates:   rates(at),
        events:  events(at),
        quakes:  quakes(at),
        network: network
      )
    end

    private

    def payload(key, at)
      entry = @store.get(key)
      source = @sources[key]
      entry.payload if source&.fresh?(entry, at)
    end

    def weather(country, at)
      places = payload(Sources::Weather::KEY, at) || {}
      [HOME, country].compact.uniq.filter_map { |c| Forecast.of(places[c]) }
    end

    def rates(at)
      data = payload(Sources::Rates::KEY, at)
      data && Rates.new(date: data['date'], huf: data['huf'])
    end

    def events(at)
      Array(payload(Sources::OnThisDay::KEY, at)&.fetch('events', nil)).map { |e| Event.new(e['year'], e['text']) }
    end

    def quakes(at)
      Array(payload(Sources::Quakes::KEY, at)&.fetch('quakes', nil)).map { |q| Quake.new(q['mag'], q['place'], q['time']) }
    end
  end
end
