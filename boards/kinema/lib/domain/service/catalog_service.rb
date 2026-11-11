# frozen_string_literal: true

require 'digest'

# The best known films as a caller browses them: the film of the day, the
# films first released on a day of the year, the decades and the genres,
# a random one, a search of their titles (for when Wikidata does not
# answer), and the refresh from Wikidata once the snapshot is +ttl+ old.
# Reads go to the snapshot's current CatalogModel; the indexes are built
# once per snapshot.
class CatalogService
  class EmptyCatalog < StandardError; end

  WEEK  = 7 * 86_400
  CHECK = 3600
  # The film of the day is one of this many best known.
  DAILY_POOL = 600
  # A genre with fewer films is no group of its own.
  MIN_GENRE  = 15
  MIN_QUERY  = 2
  MAX_RESULTS = 60

  Index = Data.define(:films, :by_id, :folded, :decades, :genres)

  # +snapshot+ is a Rubbs::Common::Storage::Snapshot of CatalogModel; a
  # genre needs +min_genre+ films to be a group.
  def initialize(snapshot, catalog: nil, ttl: WEEK, min_genre: MIN_GENRE)
    @min_genre = min_genre
    @snapshot = snapshot
    @catalog  = catalog
    @ttl      = ttl
    @lock     = Mutex.new
    @index    = nil
  end

  def films = index.films

  def count = films.size

  def find(id) = index.by_id[id]

  def generated_at = @snapshot.generated_at

  # The film of +day+: the same all day for every caller.
  def film_of_the_day(day = Date.today)
    pool = films.first(DAILY_POOL)
    return nil if pool.empty?

    pool[Digest::SHA256.hexdigest("kinema #{day.iso8601}").to_i(16) % pool.size]
  end

  # The films first released on +day+'s month and day, the best known
  # first.
  def on_this_day(day = Date.today)
    films.select { |f| f.released && f.released.month == day.month && f.released.day == day.day }
  end

  # [decade, number of films], the oldest first.
  def decades = index.decades.map { |decade, list| [decade, list.size] }

  # The films of the decade starting in +year+, the best known first.
  def of_decade(year) = index.decades.fetch(year, [])

  # [genre, number of films], the biggest first.
  def genres = index.genres.map { |name, list| [name, list.size] }

  def of_genre(name) = index.genres.fetch(name, [])

  def random = films.sample

  # The films whose title (English or Hungarian) holds +query+, the best
  # known first; :too_short for a shorter query than MIN_QUERY.
  def search(query)
    needle = fold(query)
    return :too_short if needle.size < MIN_QUERY

    idx = index
    idx.films.each_index.select { |i| idx.folded[i].include?(needle) }.first(MAX_RESULTS).map { |i| idx.films[i] }
  end

  # Reads the catalog from Wikidata when it is +ttl+ old: :ok, or :fresh.
  # Raises when Wikidata does not answer or has no films, or the snapshot
  # cannot be written; the old snapshot stays then.
  def refresh_if_stale
    @snapshot.refresh_if_older(@ttl) do
      records = @catalog.records
      raise EmptyCatalog, 'Wikidata answered no films' if records['films'].empty?

      records
    end
  end

  # +text+ in lowercase without accents and punctuation.
  def fold(text)
    text.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '').downcase.gsub(/[^\p{Alnum}]+/, ' ').strip
  end

  private

  def index
    films = @snapshot.value.films
    @lock.synchronize do
      @index = build(films) unless @index&.films.equal?(films)
      @index
    end
  end

  def build(films)
    genres = group(films, &:genres).select { |_, list| list.size >= @min_genre }
    Index.new(
      films:   films,
      by_id:   films.to_h { |f| [f.id, f] },
      folded:  films.map { |f| fold("#{f.title} #{f.hu_title}") },
      decades: group(films) { |f| f.year ? [f.year / 10 * 10] : [] }.sort.to_h,
      genres:  genres.sort_by { |name, list| [-list.size, name] }.to_h
    )
  end

  def group(films)
    films.each_with_object(Hash.new { |h, k| h[k] = [] }) do |film, groups|
      yield(film).uniq.each { |key| groups[key] << film }
    end.transform_values(&:freeze)
  end
end
