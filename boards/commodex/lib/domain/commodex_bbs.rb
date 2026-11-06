# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the catalog kept fresh
# from Wikidata, the Wikipedia leads, and the tips in SQLite, written by
# accounts of the network and approved by an admin. Both faces and the admin scripts (bin/) work on
# one instance of it.
class CommodexBBS
  include Rubbs::Common::Board::Domain

  path    :catalog_seed, 'config/catalog.json.gz'
  path    :catalog_file, 'data/catalog.json.gz', env: 'CATALOG'
  setting :catalog_ttl, 7 * 86_400
  setting :wikipedia_cache, 200
  path    :tips_db, 'data/tips.sqlite3'
  path    :tips_seed, 'config/tips.yml'
  database :tips_db, MIGRATIONS

  service(:catalog) do
    CatalogService.new(
      CatalogService.snapshot(seed: catalog_seed, path: catalog_file),
      wikidata: WikidataRepository.new,
      ttl:      catalog_ttl
    )
  end
  service(:about) { AboutService.new(WikipediaRepository.new(cache_size: wikipedia_cache)) }
  service(:tips) do
    TipService.new(catalog: catalog, seeds: TipSeedRepository.new(tips_seed).all)
  end

  # Wikidata read again when the catalog is CATALOG_TTL old; never for a TTL of 0.
  background(
    'catalog refresh',
    every:       -> { [catalog_ttl, CatalogService::RETRY_AFTER].min },
    if:          -> { catalog_ttl.positive? },
    retry_after: CatalogService::RETRY_AFTER,
    max_retry:   CatalogService::RETRY_AFTER
  ) { catalog.refresh_if_stale }
end
