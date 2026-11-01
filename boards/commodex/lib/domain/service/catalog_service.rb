# frozen_string_literal: true

# The game compendium: search by title, browse by year, genre and company,
# a random game. It reads the snapshot of the catalog repository and builds
# its indexes once per snapshot. A background thread refreshes the snapshot
# from Wikidata when it is older than +ttl+ seconds; a failed refresh keeps
# the old one and tries again after +retry_after+ seconds.
class CatalogService
  MIN_QUERY   = 2
  MAX_RESULTS = 300

  Index = Data.define(:snapshot, :by_id, :folded, :years, :genres, :companies)

  def initialize(repository, wikidata:, ttl:, retry_after: 3600)
    @repository  = repository
    @wikidata    = wikidata
    @ttl         = ttl
    @retry_after = retry_after
    @lock        = Mutex.new
    @index       = nil
  end

  def games = index.snapshot.games

  def count = games.size

  def updated_at = index.snapshot.generated_at

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

  # Starts the thread that keeps the catalog fresh; nil when +ttl+ is 0.
  # An error in a round is logged and the thread goes on after
  # +retry_after+ seconds: a refresh must not stop for good.
  def start_refresh
    return nil unless @ttl.positive?

    Thread.new { loop { refresh_round } }
  end

  # Waits until the catalog is +ttl+ old, or refreshes it now; after a
  # failed refresh, waits +retry_after+ seconds.
  def refresh_round
    age = Time.now - updated_at
    return sleep(@ttl - age) if age < @ttl
    sleep @retry_after unless refresh! == :ok
  rescue StandardError => e
    warn "commodex-bbs: catalog refresh: #{e.class}: #{e.message}"
    sleep @retry_after
  end

  # Reads the catalog from Wikidata now: :ok, or :failed (the old snapshot
  # stays).
  def refresh!
    records = @wikidata.records
    return :failed if records.nil? || records.empty?

    @repository.replace(records) ? :ok : :failed
  end

  def letter(name)
    first = GameModel.fold(name)[0]
    first&.match?(/[a-z]/) ? first : '#'
  end

  private

  def index
    snapshot = @repository.snapshot
    @lock.synchronize do
      @index = build(snapshot) unless @index&.snapshot.equal?(snapshot)
      @index
    end
  end

  def build(snapshot)
    games = snapshot.games
    Index.new(snapshot: snapshot, by_id: games.to_h { |g| [g.id, g] }, folded: games.map { |g| GameModel.fold(g.title) },
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
