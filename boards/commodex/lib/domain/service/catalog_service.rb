# frozen_string_literal: true

# The game compendium: search by title, browse by year, genre and company,
# a random game. It reads the games of the catalog file (a BBS::Snapshot)
# and builds its indexes once per snapshot. A BBS.background thread refreshes the
# snapshot from Wikidata when it is older than +ttl+ seconds; a failed
# refresh is logged, keeps the old one and tries again after +retry_after+
# seconds.
class CatalogService
  MIN_QUERY   = 2
  MAX_RESULTS = 300

  # Wikidata answered, but with no games: the old snapshot stays.
  class EmptyCatalog < StandardError; end

  SOURCE = 'Wikidata, https://www.wikidata.org (CC0 1.0)'

  Index = Data.define(:games, :by_id, :folded, :years, :genres, :companies)

  # The catalog file kept whole in memory: the newer of +seed+ and +path+,
  # its records the games.
  def self.snapshot(seed:, path:)
    BBS::Snapshot.new(seed: seed, path: path, source: SOURCE) do |records|
      names = {}
      Array(records['games']).filter_map { |r| GameModel.from_record(r, names) }.freeze
    end
  end

  def initialize(snapshot, wikidata:, ttl:, retry_after: 3600)
    @snapshot    = snapshot
    @wikidata    = wikidata
    @ttl         = ttl
    @retry_after = retry_after
    @lock        = Mutex.new
    @index       = nil
  end

  def games = index.games

  def count = games.size

  def updated_at = @snapshot.generated_at

  def find(id) = index.by_id[id]

  # The games whose title holds +query+ (case, accents and punctuation
  # aside), those starting with it first; :too_short for a query of fewer
  # than MIN_QUERY letters or digits.
  def search(query)
    needle = GameModel.fold(query)
    return :too_short if needle.size < MIN_QUERY

    idx  = index
    hits = idx.folded.each_index.select { |i| idx.folded[i].include?(needle) }
    hits.sort_by { |i| [idx.folded[i].start_with?(needle) ? 0 : 1, i] }.first(MAX_RESULTS).map { |i| games[i] }
  end

  # [year, number of games], oldest first; games without a year left out.
  def years = index.years.map { |year, list| [year, list.size] }

  def in_year(year) = index.years.fetch(year, [])

  # [genre, number of games], the biggest first.
  def genres = index.genres.map { |name, list| [name, list.size] }.sort_by { |name, n| [-n, name.downcase] }

  def of_genre(name) = index.genres.fetch(name, [])

  # [letter, number of companies]: a to z, and # for the rest.
  def letters
    index.companies.keys.group_by { |name| letter(name) }.map { |l, names| [l, names.size] }.sort_by do |l, _|
      l == '#' ? '' : l
    end
  end

  # [company, number of games] of the publishers and developers under +letter+.
  def companies(letter)
    index.companies.select { |name, _| letter(name) == letter }.map { |name, list| [name, list.size] }
  end

  def of_company(name) = index.companies.fetch(name, [])

  def random = games.sample

  # Starts the BBS.background thread that keeps the catalog fresh: it looks
  # at the snapshot's age every +ttl+ seconds (at least hourly). nil when
  # +ttl+ is 0.
  def start_refresh
    return nil unless @ttl.positive?

    BBS.background('catalog refresh', every: [@ttl, @retry_after].min, retry_after: @retry_after,
                                      max_retry: @retry_after) { refresh_if_stale }
  end

  # Reads the catalog from Wikidata when it is +ttl+ old: :ok, or :fresh.
  # Raises when Wikidata does not answer or has no games, or the snapshot
  # cannot be written; the old snapshot stays then.
  def refresh_if_stale
    @snapshot.refresh_if_older(@ttl) do
      records = @wikidata.records
      raise EmptyCatalog, 'Wikidata answered no games' if records.empty?

      { 'games' => records }
    end
  end

  def letter(name)
    first = GameModel.fold(name)[0]
    first&.match?(/[a-z]/) ? first : '#'
  end

  private

  def index
    games = @snapshot.value
    @lock.synchronize do
      @index = build(games) unless @index&.games.equal?(games)
      @index
    end
  end

  def build(games)
    Index.new(games: games, by_id: games.to_h { |g| [g.id, g] }, folded: games.map { |g| GameModel.fold(g.title) },
              years: sorted(group(games) { |g| [g.year].compact }) { |y, _| y },
              genres: sorted(group(games, &:genres)) { |n, _| n.downcase },
              companies: sorted(group(games, &:companies)) { |n, _| GameModel.fold(n) })
  end

  # The games under each of the keys the block gives for a game.
  def group(games)
    games.each_with_object(Hash.new { |h, k| h[k] = [] }) do |game, groups|
      yield(game).each { |key| groups[key] << game }
    end
  end

  def sorted(hash, &) = hash.sort_by(&).to_h { |k, list| [k, list.freeze] }.freeze
end
