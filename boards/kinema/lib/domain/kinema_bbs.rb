# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the catalog of the best
# known films kept fresh from Wikidata, Wikidata and Wikipedia asked live
# for everything else, and the callers' ratings and lists in SQLite. Both
# faces and the admin script (bin/reviews) work on one instance of it.
class KinemaBBS
  include Rubbs::Common::Board::Domain

  SOURCE = 'Wikidata, https://www.wikidata.org (CC0 1.0)'

  path     :catalog_seed, 'config/catalog.json.gz'
  path     :catalog_file, 'data/catalog.json.gz', env: 'CATALOG'
  setting  :catalog_ttl, CatalogService::WEEK
  path     :ratings_db, 'data/ratings.sqlite3'
  database :ratings_db, MIGRATIONS

  service(:catalog) { CatalogService.new(snapshot, catalog: CatalogRepository.new, ttl: catalog_ttl) }
  service(:films) do
    FilmService.new(wikidata: WikidataRepository.new, wikipedia: WikipediaRepository.new, catalog: catalog)
  end
  service(:ratings) { RatingService.new }

  # Wikidata read again when the catalog is CATALOG_TTL old; never for a TTL of 0.
  background('catalog', every: CatalogService::CHECK, if: -> { catalog_ttl.positive? }) { catalog.refresh_if_stale }

  private

  def snapshot
    Rubbs::Common::Storage::Snapshot.new(seed: catalog_seed, path: catalog_file, source: SOURCE) do |records|
      CatalogModel.from_records(records)
    end
  end
end
