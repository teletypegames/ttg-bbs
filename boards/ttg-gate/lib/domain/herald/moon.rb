# frozen_string_literal: true

module Herald
  # The phase of the moon at an instant, worked out from a known new moon
  # and the mean synodic month: good to a few hours, enough for a name and a
  # share lit.
  module Moon
    # The mean synodic month, in days.
    SYNODIC = 29.530588853
    # A new moon: 6 January 2000, 18:14 UTC.
    EPOCH = Time.utc(2000, 1, 6, 18, 14)
    # The eight phases, from the new moon on, with their mark.
    PHASES = [
      ['new moon', '●'], ['waxing crescent', '◐'], ['first quarter', '◐'], ['waxing gibbous', '◐'],
      ['full moon', '○'], ['waning gibbous', '◑'], ['last quarter', '◑'], ['waning crescent', '◑']
    ].freeze

    # A phase: its +name+, the +age+ of the moon in days, the share lit
    # (+illumination+, 0..1) and a +mark+ to draw.
    Phase = Data.define(:name, :age, :illumination, :mark) do
      # The share lit in per cent.
      def percent = (illumination * 100).round
    end

    module_function

    # The Phase at +time+.
    def at(time)
      age = ((time.to_f - EPOCH.to_f) / 86_400) % SYNODIC
      name, mark = PHASES[((age / SYNODIC * 8) + 0.5).floor % 8]
      Phase.new(name: name, age: age, illumination: (1 - Math.cos(2 * Math::PI * age / SYNODIC)) / 2, mark: mark)
    end
  end
end
