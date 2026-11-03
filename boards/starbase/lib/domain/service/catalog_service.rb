# frozen_string_literal: true

# The catalog as a caller browses it: the series, a series by seasons, the
# episodes that first aired on a day of the year, and the refresh from
# Wikidata once the snapshot is +ttl+ old. Reads go to the repository's
# current snapshot.
class CatalogService
  class EmptyCatalog < StandardError; end

  WEEK  = 7 * 86_400
  CHECK = 3600

  def initialize(repository, wikidata: nil, ttl: WEEK)
    @repository = repository
    @wikidata   = wikidata
    @ttl        = ttl
  end

  # Checks every hour, in the background, whether the catalog is due.
  def start_refresh = BBS.background('catalog', every: CHECK) { refresh_if_stale }

  def series = @repository.snapshot.series

  # The episodes of +series+ in order: by season and number, by their
  # number in the series, by air date; the films by date.
  def episodes(series)
    @repository.snapshot.episodes.select { |e| e.series_id == series.id }
               .sort_by { |e| [e.season || 999, e.number || e.ordinal || 999, e.aired || Date.new(9999), e.title] }
  end

  # +series+'s episodes as [[season, episodes]] pairs, in order; one pair
  # with season nil for the films or a series without seasons.
  def seasons(series) = episodes(series).group_by(&:season).to_a

  # The episodes and films that first aired on +day+'s month and day, the
  # oldest first, with the series of each: [[episode, series], ...].
  def on_this_day(day)
    by_id = series.to_h { |s| [s.id, s] }
    @repository.snapshot.episodes
               .select { |e| e.aired && e.aired.month == day.month && e.aired.day == day.day }
               .sort_by(&:aired).filter_map { |e| by_id[e.series_id]&.then { |s| [e, s] } }
  end

  def series_of(episode) = series.find { |s| s.id == episode.series_id }

  def size = @repository.snapshot.episodes.size

  def generated_at = @repository.snapshot.generated_at

  # Reads the catalog from Wikidata when it is +ttl+ old: :ok, or :fresh.
  # Raises when Wikidata does not answer or has no episodes, or the
  # snapshot cannot be written; the old snapshot stays then.
  def refresh_if_stale
    return :fresh if Time.now - generated_at < @ttl

    records = @wikidata.records
    raise EmptyCatalog, 'Wikidata answered no episodes' if records['episodes'].empty?

    @repository.replace(records)
    :ok
  end
end
