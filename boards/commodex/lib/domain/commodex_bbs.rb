# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the catalog wired to its
# snapshot and Wikidata, the Wikipedia leads, and the tips in SQLite with
# the admins' Discord rung for a new one. The one place that reads ENV. Both
# faces (lib/ui/modern, lib/ui/petscii) and the admin scripts (bin/) work on
# one instance of it.
class CommodexBBS
  ROOT = File.expand_path('../..', __dir__)

  attr_reader :catalog, :about, :tips

  def initialize(env = ENV)
    @env     = env
    @catalog = catalog_service
    @about   = AboutService.new(WikipediaRepository.new(cache_size: Integer(env.fetch('COMMODEX_BBS_WIKIPEDIA_CACHE', '200'))))
    @tips    = tip_service
  end

  # Starts keeping the catalog fresh from Wikidata in the background.
  def start = @catalog.start_refresh

  # The services by name.
  def services = { catalog: @catalog, about: @about, tips: @tips }

  private

  def path(name, default) = @env.fetch(name, File.join(ROOT, default))

  def catalog_service
    repository = CatalogRepository.new(seed: path('COMMODEX_BBS_CATALOG_SEED', 'config/catalog.json.gz'),
                                       path: path('COMMODEX_BBS_CATALOG', 'data/catalog.json.gz'))
    CatalogService.new(repository, wikidata: WikidataRepository.new,
                                   ttl: Integer(@env.fetch('COMMODEX_BBS_CATALOG_TTL', (7 * 86_400).to_s)))
  end

  def tip_service
    db      = BBS::SQLite.new(path('COMMODEX_BBS_TIPS_DB', 'data/tips.sqlite3'))
    seeds   = TipSeedRepository.new(path('COMMODEX_BBS_TIPS_SEED', 'config/tips.yml')).all
    webhook = @env['COMMODEX_BBS_DISCORD_WEBHOOK'].to_s
    TipService.new(TipRepository.new(db), catalog: @catalog, seeds: seeds,
                                          notifier: webhook.empty? ? nil : DiscordNotifier.new(webhook: webhook))
  end
end
