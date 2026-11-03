# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the one place that
# reads ENV and wires the repositories to the services. Both faces
# (lib/ui/modern, lib/ui/petscii) work on one instance.
class StarbaseBBS
  ROOT = File.expand_path('../..', __dir__)

  attr_reader :catalog, :library

  def initialize(env = ENV)
    @env     = env
    @catalog = catalog_service
    @library = LibraryService.new(MemoryAlphaRepository.new)
  end

  # Starts keeping the catalog fresh from Wikidata in the background.
  def start = @catalog.start_refresh

  # The services by name.
  def services = { catalog: @catalog, library: @library }

  private

  def path(name, default) = @env.fetch(name, File.join(ROOT, default))

  def catalog_service
    repository = CatalogRepository.new(seed: path('STARBASE_BBS_CATALOG_SEED', 'config/catalog.json.gz'),
                                       path: path('STARBASE_BBS_CATALOG', 'data/catalog.json.gz'))
    CatalogService.new(repository, wikidata: WikidataRepository.new,
                                   ttl: Integer(@env.fetch('STARBASE_BBS_CATALOG_TTL', CatalogService::WEEK.to_s)))
  end
end
