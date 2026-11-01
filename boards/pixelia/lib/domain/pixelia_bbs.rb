# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the ANSI gallery wired to
# 16colo.rs and the disk cache, the shared canvas and the Wall. Both faces
# (lib/ui/modern, lib/ui/petscii) work on one instance of it, so a C64 and an
# ANSI terminal paint on the same canvas.
class PixeliaBBS
  ROOT = File.expand_path('../..', __dir__)
  USER_AGENT = 'PixeliaBBS/1.0 (+https://teletypegames.org; telnet art board of Teletype Games)'

  attr_reader :gallery, :canvas, :wall, :canvas_repository

  def initialize(start: true)
    data = ENV.fetch('PIXELIA_DATA', File.join(ROOT, 'data'))
    remote = SixteenColorsRepository.new(api_url: ENV.fetch('PIXELIA_API_URL', 'https://api.16colo.rs'),
                                         site_url: ENV.fetch('PIXELIA_SITE_URL', 'https://16colo.rs'),
                                         user_agent: ENV.fetch('PIXELIA_USER_AGENT', USER_AGENT),
                                         ttl: Integer(ENV.fetch('PIXELIA_API_TTL', '3600')),
                                         max_bytes: Integer(ENV.fetch('PIXELIA_MAX_FILE_KB', '512')) * 1024)
    cache = ArtCacheRepository.new(File.join(data, 'cache'),
                                   max_bytes: Integer(ENV.fetch('PIXELIA_CACHE_MB', '100')) * 1024 * 1024)
    @gallery = GalleryService.new(remote: remote, cache: cache,
                                  renderer: AnsiRenderService.new(max_rows: Integer(ENV.fetch('PIXELIA_MAX_ROWS', '1000'))))

    @canvas_repository = CanvasRepository.new(File.join(data, 'canvas.json'), archive_dir: File.join(data, 'archive'),
                                                                               clear_flag: File.join(data, 'canvas.clear'))
    @canvas_repository.start if start
    @canvas = CanvasService.new(@canvas_repository, rate: Integer(ENV.fetch('PIXELIA_PAINT_RATE', '20')))
    @wall   = WallService.new(WorkRepository.new(File.join(data, 'works')), canvas: @canvas,
                              cooldown: Integer(ENV.fetch('PIXELIA_WALL_COOLDOWN', '300')))
  end

  # The services by name.
  def services = { gallery: @gallery, canvas: @canvas, wall: @wall }
end
