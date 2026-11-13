# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the catalog kept fresh from Wikidata, the
# Wikipedia leads, the Commons photos, the callers' marks, memories and views in SQLite, and the
# machine of the week for the network's Daily Herald. Both faces and the admin
# scripts (bin/) work on one instance of it.
class SiliconiaBBS
  include Rubbs::Common::Board::Domain

  path    :catalog_seed, 'config/catalog.json.gz'
  path    :catalog_file, 'data/catalog.json.gz', env: 'CATALOG'
  path    :legends_file, 'config/legends.yml', env: 'LEGENDS'
  setting :catalog_ttl, 7 * 86_400
  setting :wikipedia_cache, 200
  path    :db, 'data/siliconia.sqlite3'
  path    :pictures_dir, 'data/pictures', env: 'PICTURES'
  path    :herald_file, 'data/herald.json', env: 'HERALD'
  database :db, MIGRATIONS

  service(:catalog) do
    CatalogService.new(
      CatalogService.snapshot(seed: catalog_seed, path: catalog_file),
      wikidata: WikidataRepository.new,
      ttl:      catalog_ttl,
      legends:  LegendRepository.new(legends_file).ids
    )
  end
  service(:about) { AboutService.new(WikipediaRepository.new(cache_size: wikipedia_cache)) }
  service(:collection) { CollectionService.new(catalog: catalog) }
  service(:memories) { MemoryService.new(catalog: catalog) }
  service(:pictures) { PictureService.new(commons: CommonsRepository.new, pixels: PixelRepository.new, dir: pictures_dir) }
  service(:herald) { HeraldService.new(catalog: catalog, path: herald_file) }

  # The machine of the week for the Daily Herald of TTG Gate BBS.
  background('herald', every: 3600) { herald.publish }

  # Wikidata read again when the catalog is CATALOG_TTL old; never for a TTL of 0.
  background(
    'catalog refresh',
    every:       -> { [catalog_ttl, CatalogService::RETRY_AFTER].min },
    if:          -> { catalog_ttl.positive? },
    retry_after: CatalogService::RETRY_AFTER,
    max_retry:   CatalogService::RETRY_AFTER
  ) { catalog.refresh_if_stale }
end
