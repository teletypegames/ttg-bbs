# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the catalog wired to its
# snapshot and Wikidata, the Wikipedia leads, and the tips in SQLite with
# the admins' Discord rung for a new one. Both faces (lib/ui/modern,
# lib/ui/petscii) and the admin scripts (bin/) work on one instance of it.
class CommodexBBS
  ROOT = File.expand_path('../..', __dir__)

  attr_reader :catalog, :about, :tips

  def initialize
    catalog_repo = CatalogRepository.new(seed: ENV.fetch('COMMODEX_BBS_CATALOG_SEED', File.join(ROOT, 'config/catalog.json.gz')),
                                         path: ENV.fetch('COMMODEX_BBS_CATALOG', File.join(ROOT, 'data/catalog.json.gz')))
    @catalog = CatalogService.new(catalog_repo, wikidata: WikidataRepository.new,
                                                ttl: Integer(ENV.fetch('COMMODEX_BBS_CATALOG_TTL', (7 * 86_400).to_s)))
    @about   = AboutService.new(WikipediaRepository.new(cache_size: Integer(ENV.fetch('COMMODEX_BBS_WIKIPEDIA_CACHE', '200'))))

    db       = SqliteDatabase.new(ENV.fetch('COMMODEX_BBS_TIPS_DB', File.join(ROOT, 'data/tips.sqlite3')))
    webhook  = ENV['COMMODEX_BBS_DISCORD_WEBHOOK'].to_s
    seeds    = TipSeedRepository.new(ENV.fetch('COMMODEX_BBS_TIPS_SEED', File.join(ROOT, 'config/tips.yml'))).all
    @tips    = TipService.new(TipRepository.new(db), catalog: @catalog, seeds: seeds,
                                                     notifier: webhook.empty? ? nil : DiscordNotifier.new(webhook: webhook))
  end

  # Starts keeping the catalog fresh from Wikidata in the background.
  def start = @catalog.start_refresh

  # The services by name.
  def services = { catalog: @catalog, about: @about, tips: @tips }
end
