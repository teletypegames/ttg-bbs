# frozen_string_literal: true

module UI
  # The pictures of the clubhouse (Rubbs::Common::Art YAML under lib/content/art),
  # one folder for each face: modern (code page 437, 256 colours) and c64
  # (the uppercase/graphics set). An art is read once, with each set of
  # layers stacked once, and kept.
  module Arts
    DIR = File.expand_path('../content/art', __dir__)

    @cache = {}
    @mutex = Mutex.new

    # The art +name+ of +face+ (:modern or :c64) with +layers+ stacked (only
    # those the art lists are taken).
    def self.load(face, name, layers = [])
      key = [face, name.to_s, layers.map(&:to_s)]
      @mutex.synchronize do
        @cache[key] ||= Rubbs::Common::Art.load(File.join(DIR, face.to_s, "#{name}.yml")).with(*layers)
      end
    end

    # The clubhouse from the street for +season+ (a Rubbs::Common::Season): the
    # picture of its time of day (house_<time>) with the layers of its
    # season drawn for that time (snow_<time>, pumpkin_<time>, …).
    def self.house(face, season)
      time = season.time_of_day
      load(face, "house_#{time}", season.layers.map { |layer| "#{layer}_#{time}" })
    end

    # The ANSI colour of the background of +art+'s cell at +col+, +row+, as
    # an SGR parameter (<tt>48;5;n</tt>), or '' for none: a hotspot's
    # filling keeps the picture behind it.
    def self.bg(art, col, row)
      color = art.cell(col, row)&.bg
      color ? ";48;5;#{color.ansi}" : ''
    end
  end
end
