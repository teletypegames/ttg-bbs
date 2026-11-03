# frozen_string_literal: true

require 'date'

# An episode of a series, or a film: its Wikidata id, title, series, its
# season and number in it, its number in the whole series, the day it
# first aired, its directors and writers, and its Memory Alpha article.
EpisodeModel = Data.define(:id, :title, :series_id, :season, :number, :ordinal, :aired, :directors, :writers, :ma) do
  def self.from_record(record)
    new(id: record['id'].to_s, title: line(record['t']), series_id: record['se'].to_s,
        season: record['sn']&.to_i, number: record['n']&.to_i, ordinal: record['o']&.to_i,
        aired: date(record['d']), directors: names(record['dir']), writers: names(record['wr']),
        ma: record['ma']&.then { |title| line(title) })
  end

  def self.line(text) = BBS::Text.line(text)

  def self.names(list) = Array(list).map { |name| line(name) }.reject(&:empty?).freeze

  def self.date(text)
    text && Date.iso8601(text)
  rescue Date::Error
    nil
  end

  # "S3E15", "S1" without a number, "" without a season.
  def code
    return '' unless season

    number ? format('S%<s>dE%<n>02d', s: season, n: number) : "S#{season}"
  end

  # The year it first aired, or nil.
  def year = aired&.year

  # How a list shows it: "S3E15 Yesterday's Enterprise", or a film's year
  # and title.
  def label = [code.empty? ? year : code, title].compact.join(' ').strip
end
