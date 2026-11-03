# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the catalog snapshot kept
# fresh from Wikidata, and Memory Alpha to read.
class StarbaseBBS
  include BBS::Domain

  SOURCE = 'Wikidata, https://www.wikidata.org (CC0 1.0)'

  path    :catalog_seed, 'config/catalog.json.gz'
  path    :catalog_file, 'data/catalog.json.gz', env: 'CATALOG'
  setting :catalog_ttl, CatalogService::WEEK

  service(:catalog) { CatalogService.new(snapshot, wikidata: WikidataRepository.new, ttl: catalog_ttl) }
  service(:library) { LibraryService.new(MemoryAlphaRepository.new) }

  background('catalog', every: CatalogService::CHECK) { catalog.refresh_if_stale }

  private

  def snapshot
    BBS::Snapshot.new(seed: catalog_seed, path: catalog_file, source: SOURCE) { |records| CatalogModel.from_records(records) }
  end
end
