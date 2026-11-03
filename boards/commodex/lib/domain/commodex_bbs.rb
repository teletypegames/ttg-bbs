# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the catalog kept fresh
# from Wikidata, the Wikipedia leads, and the tips in SQLite with the admins'
# Discord rung for a new one. Both faces and the admin scripts (bin/) work on
# one instance of it.
class CommodexBBS
  include BBS::Domain

  path    :catalog_seed, 'config/catalog.json.gz'
  path    :catalog_file, 'data/catalog.json.gz'
  setting :catalog_ttl, 7 * 86_400
  setting :wikipedia_cache, 200
  path    :tips_db, 'data/tips.sqlite3'
  path    :tips_seed, 'config/tips.yml'
  setting :discord_webhook, ''

  service(:catalog) do
    CatalogService.new(CatalogService.snapshot(seed: catalog_seed, path: catalog_file),
                       wikidata: WikidataRepository.new, ttl: catalog_ttl)
  end
  service(:about) { AboutService.new(WikipediaRepository.new(cache_size: wikipedia_cache)) }
  service(:tips) do
    TipService.new(TipRepository.new(database(tips_db)), catalog: catalog, seeds: TipSeedRepository.new(tips_seed).all,
                                                         notifier: notifier)
  end

  # The services, and the catalog refresh unless COMMODEX_BBS_CATALOG_TTL is 0.
  def start
    super
    catalog.start_refresh
    self
  end

  private

  def notifier = discord_webhook.empty? ? nil : DiscordNotifier.new(webhook: discord_webhook)
end
