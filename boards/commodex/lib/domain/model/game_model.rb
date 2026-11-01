# frozen_string_literal: true

# One Commodore 64 game of the catalog, as Wikidata describes it: its QID,
# title, first year on the C64 (or at all), the English Wikipedia article and
# the names of its publishers, developers, designers, composers, genres, game
# modes and series. The lists are frozen arrays of frozen strings, shared
# between games where the names are equal, so 3,000 games stay small.
GameModel = Data.define(:id, :title, :year, :article, :publishers, :developers, :designers, :composers,
                        :genres, :modes, :series) do
  # The game of a catalog record; nil without an id or a title. +names+ is
  # a Hash that interns the strings shared between games.
  def self.from_record(record, names = {})
    id    = record['id'].to_s
    title = record['t'].to_s.strip
    return nil unless id.match?(/\AQ\d+\z/) && !title.empty?

    lists = GameModel::LISTS.to_h do |key|
      [key, Array(record[GameModel::KEYS[key]]).map { |n| names[n.to_s] ||= n.to_s.dup.freeze }.uniq.freeze]
    end
    new(id: -id, title: -title, year: record['y']&.to_i, article: record['w']&.then { |w| -w.to_s },
        **lists)
  end

  # The game as a record of the catalog file, empty fields left out.
  def to_record
    GameModel::KEYS.each_with_object({}) do |(key, short), out|
      value = public_send(key)
      out[short] = value unless value.nil? || (value.respond_to?(:empty?) && value.empty?)
    end
  end

  # The title folded for a search: lowercase, no accents, letters and
  # digits only.
  def self.fold(text)
    text.to_s.unicode_normalize(:nfkd).downcase.gsub(/[^a-z0-9]/, '')
  end

  def companies = (publishers + developers).uniq

  def wikidata_url = "https://www.wikidata.org/wiki/#{id}"

  def wikipedia_url = article && "https://en.wikipedia.org/wiki/#{article.tr(' ', '_')}"

  def label = year ? "#{title} (#{year})" : title
end

GameModel::LISTS = %i[publishers developers designers composers genres modes series].freeze
# The short keys of a record in the catalog file.
GameModel::KEYS = { id: 'id', title: 't', year: 'y', article: 'w', publishers: 'pub', developers: 'dev',
                    designers: 'des', composers: 'mus', genres: 'gen', modes: 'mod', series: 'ser' }.freeze
