# frozen_string_literal: true

require 'date'

# A film of the catalog file, the films Wikidata knows best (by the number
# of wikis that have an article on it): its Wikidata id, English and
# Hungarian titles, the year and day it was first released, that number of
# wikis, its directors and genres. Built from a record of the catalog file
# (short keys, see CatalogRepository).
CatalogFilmModel = Data.define(:id, :title, :hu_title, :year, :released, :links, :directors, :genres) do
  def self.from_record(record)
    new(
      id:        record['id'].to_s,
      title:     line(record['t']),
      hu_title:  record['hu']&.then { |t| line(t) },
      year:      record['y']&.to_i,
      released:  date(record['d']),
      links:     record['l'].to_i,
      directors: names(record['dir']),
      genres:    names(record['g']).map { |g| genre(g) }.uniq.freeze
    )
  end

  def self.line(text) = Rubbs::Common::Text.line(text)

  def self.names(list) = Array(list).map { |name| line(name) }.reject(&:empty?).freeze

  # "science fiction film" is "science fiction".
  def self.genre(name) = name.sub(/ film\z/, '')

  def self.date(text)
    text && Date.iso8601(text)
  rescue Date::Error
    nil
  end

  # How a list shows it: "1979 Stalker".
  def label = [year, title].compact.join(' ')

  # One line about it: "Andrei Tarkovsky · science fiction, drama".
  def note = [directors.first(2).join(', '), genres.first(3).join(', ')].reject(&:empty?).join(' · ')
end
