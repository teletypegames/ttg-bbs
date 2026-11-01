# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the ANSI gallery wired to
# 16colo.rs and the disk cache, the shared canvas and the Wall. Both faces
# (lib/ui/modern, lib/ui/petscii) work on one instance of it, so a C64 and an
# ANSI terminal paint on the same canvas. The only place that reads ENV.
class PixeliaBBS
  ROOT = File.expand_path('../..', __dir__)
  USER_AGENT = 'PixeliaBBS/1.0 (+https://teletypegames.org; telnet art board of Teletype Games)'

  attr_reader :gallery, :canvas, :wall, :canvas_repository

  def initialize(start: true)
    @data = env('DATA', File.join(ROOT, 'data'))
    @gallery = build_gallery
    @canvas_repository = CanvasRepository.new(File.join(@data, 'canvas.json'), archive_dir: File.join(@data, 'archive'),
                                                                                clear_flag: File.join(@data, 'canvas.clear'))
    @canvas_repository.start if start
    @canvas = CanvasService.new(@canvas_repository, rate: number('PAINT_RATE', 20))
    @wall   = WallService.new(WorkRepository.new(File.join(@data, 'works')), canvas: @canvas,
                              cooldown: number('WALL_COOLDOWN', 300), per_hour: number('WALL_PER_HOUR', 30))
  end

  # The services by name.
  def services = { gallery: @gallery, canvas: @canvas, wall: @wall }

  private

  def build_gallery
    remote = SixteenColorsRepository.new(api_url: env('API_URL', 'https://api.16colo.rs'),
                                         site_url: env('SITE_URL', 'https://16colo.rs'),
                                         user_agent: env('USER_AGENT', USER_AGENT),
                                         ttl: number('API_TTL', 3600), max_bytes: number('MAX_FILE_KB', 512) * 1024)
    cache = ArtCacheRepository.new(File.join(@data, 'cache'), max_bytes: number('CACHE_MB', 100) * 1024 * 1024)
    GalleryService.new(remote: remote, cache: cache, renderer: AnsiRenderService.new(max_rows: number('MAX_ROWS', 1000)))
  end

  def env(name, default) = ENV.fetch("PIXELIA_BBS_#{name}", default)

  def number(name, default) = Integer(env(name, default.to_s))
end
