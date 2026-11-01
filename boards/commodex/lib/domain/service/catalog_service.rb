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
  def start_refresh
    return nil unless @ttl.positive?

    Thread.new do
      loop do
        age = Time.now - updated_at
        if age < @ttl
          sleep(@ttl - age)
        elsif refresh! != :ok
          sleep @retry_after
        end
      end
    end
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
    games     = snapshot.games
    years     = Hash.new { |h, k| h[k] = [] }
    genres    = Hash.new { |h, k| h[k] = [] }
    companies = Hash.new { |h, k| h[k] = [] }
    games.each do |g|
      years[g.year] << g if g.year
      g.genres.each { |name| genres[name] << g }
      g.companies.each { |name| companies[name] << g }
    end
    Index.new(snapshot: snapshot, by_id: games.to_h { |g| [g.id, g] }, folded: games.map { |g| GameModel.fold(g.title) },
              years: sorted(years) { |y, _| y }, genres: sorted(genres) { |n, _| n.downcase },
              companies: sorted(companies) { |n, _| GameModel.fold(n) })
  end

  def sorted(hash, &) = hash.sort_by(&).to_h { |k, list| [k, list.freeze] }.freeze
end
