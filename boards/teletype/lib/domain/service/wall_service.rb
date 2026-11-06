# frozen_string_literal: true

require 'time'

# This board's wall on the network's Central (ttg-common TTG::Wall) as the
# clubhouse reads it: the newest notes (the graffiti wall, the bulletin),
# when the last one was written (the chimney smoke) and who wrote the most
# of them (the trophy case). The newest NOTES are asked at most every TTL
# seconds, whoever draws, so drawing a scene does not ask the Central each
# time; the wall is empty while the Central does not answer.
class WallService
  NOTES = 100
  TTL   = 30

  # +source+ answers the newest notes for a count (TTG::Wall.lines by
  # default); +ttl+ the seconds they are kept.
  def initialize(source: ->(count) { TTG::Wall.lines(count) }, ttl: TTL)
    @source = source
    @cache  = Rubbs::Common::Storage::Cache.new(ttl: ttl, max_entries: 1)
  end

  # The newest +count+ notes, oldest first: Hashes with String keys (+name+,
  # +text+, +created_at+, +guest+, …).
  def recent(count) = notes.last(count)

  # When the newest note was written (a Time), +nil+ for an empty wall.
  def written_at
    stamp = notes.last&.fetch('created_at', nil) or return nil
    Time.iso8601(stamp)
  rescue ArgumentError
    nil
  end

  # [[name, notes], ...] of the names with the most of the newest notes,
  # the most first; a guest's notes are not counted.
  def top_writers(count)
    names = notes.reject { |note| note['guest'] }.map { |note| note['name'].to_s }
    names.tally.sort_by { |name, n| [-n, name.downcase] }.first(count)
  end

  private

  def notes = @cache.fetch(:notes) { Array(@source.call(NOTES)) }
end
