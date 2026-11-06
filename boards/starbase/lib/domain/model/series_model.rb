# frozen_string_literal: true

# A series of the franchise, or the films taken as one: its Wikidata id,
# its title, the years it ran and its Memory Alpha article. Built from a
# record of the catalog file (short keys, see WikidataRepository).
SeriesModel = Data.define(:id, :title, :start, :finish, :ma) do
  def self.from_record(record)
    new(
      id:     record['id'].to_s,
      title:  Rubbs::Common::Text.line(record['t']),
      start:  record['s']&.to_i,
      finish: record['e']&.to_i,
      ma:     record['ma']&.then { |title| Rubbs::Common::Text.line(title) }
    )
  end

  def films? = id == SeriesModel::FILMS

  # The years it ran, "1987–1994", "2017–" while it runs, "" when unknown.
  def years
    return '' unless start
    return start.to_s if finish == start

    "#{start}–#{finish}"
  end

  # The title without the franchise's name before it: "The Next Generation".
  def short_title = title.sub(/\AStar Trek: /, '')

  # The abbreviation the fans use, "TNG", "DS9"; the capitals of the short
  # title for a series they have none for.
  def abbreviation
    return 'Film' if films?

    SeriesModel::ABBREVIATIONS.fetch(short_title) { short_title.scan(/\b[A-Z0-9]/).join[0, 3] }
  end
end

class SeriesModel
  # The id of the pseudo-series of the films.
  FILMS = 'films'
  # The fans' abbreviations of the series, by short title.
  ABBREVIATIONS = {
    'The Original Series' => 'TOS',
    'The Animated Series' => 'TAS',
    'The Next Generation' => 'TNG',
    'Deep Space Nine'     => 'DS9',
    'Voyager'             => 'VOY',
    'Enterprise'          => 'ENT',
    'Discovery'           => 'DIS',
    'Short Treks'         => 'ST',
    'Lower Decks'         => 'LD',
    'Picard'              => 'PIC',
    'Prodigy'             => 'PRO',
    'Strange New Worlds'  => 'SNW',
    'Very Short Treks'    => 'VST',
    'Starfleet Academy'   => 'SFA'
  }.freeze
end
