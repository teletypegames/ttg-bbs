# frozen_string_literal: true

module Trophies
  # One of the five most downloaded titles.
  Entry = Data.define(:title, :engine, :downloads)

  # Where each number is in the Source's payload: field => [part, key].
  ROOM_FIELDS = {
    downloads:  %w[downloads count],
    visitors:   %w[downloads visitors],
    commits:    %w[commits count],
    repos:      %w[commits repos],
    teletypers: %w[team members],
    candidates: %w[team candidates],
    runs:       %w[ci runs],
    green:      %w[ci green],
    released:   %w[catalog released],
    titles:     %w[catalog titles],
    platforms:  %w[catalog platforms],
    categories: %w[catalog categories]
  }.freeze

  # What a caller sees in the Trophy Room: the numbers of Trophies::Source
  # (+nil+ each that never came) and the network's own (+boards+,
  # +accounts+), +updated_at+ (epoch seconds) when the numbers came.
  Room = Data.define(
    :top,
    :downloads,
    :visitors,
    :commits,
    :repos,
    :teletypers,
    :candidates,
    :runs,
    :green,
    :released,
    :titles,
    :platforms,
    :categories,
    :boards,
    :accounts,
    :updated_at
  ) do
    # A Room of the Source's +payload+ (or +nil+) and the network's numbers.
    def self.of(payload, boards:, accounts:, updated_at:)
      p = payload || {}
      new(
        top:        Array(p['top']).map { |e| Entry.new(e['title'].to_s, e['engine'].to_s, e['downloads'].to_i) },
        **ROOM_FIELDS.to_h { |field, (part, key)| [field, p[part]&.fetch(key, nil)] },
        boards:     boards,
        accounts:   accounts,
        updated_at: payload && updated_at
      )
    end

    # Whether any number of the Source came.
    def ready? = !updated_at.nil?

    # The Teletypers who are not candidates any more.
    def core = teletypers && candidates && (teletypers - candidates)

    # The share of green pipelines in per cent, or +nil+.
    def green_percent = green && (green * 100).round

    # The most downloads of a title (for the bars).
    def most = top.map(&:downloads).max.to_i
  end
end
