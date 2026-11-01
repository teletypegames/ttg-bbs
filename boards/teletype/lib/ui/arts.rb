# frozen_string_literal: true

module UI
  # The pictures of the clubhouse (BBS::Art YAML under lib/content/art),
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
        @cache[key] ||= BBS::Art.load(File.join(DIR, face.to_s, "#{name}.yml")).with(*layers)
      end
    end

    # The clubhouse from the street for +season+ (a BBS::Season): the
    # picture of its time of day with the layers of its season.
    def self.house(face, season) = load(face, "house_#{season.time_of_day}", season.layers)

    # The ANSI colour of the background of +art+'s cell at +col+, +row+, as
    # an SGR parameter (<tt>48;5;n</tt>), or '' for none: a hotspot's
    # filling keeps the picture behind it.
    def self.bg(art, col, row)
      color = art.cell(col, row)&.bg
      color ? ";48;5;#{color.ansi}" : ''
    end
  end
end
