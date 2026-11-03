# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the ANSI gallery wired to
# 16colo.rs and the disk cache, the shared canvas and the Wall. Both faces
# (lib/ui/modern, lib/ui/petscii) work on one instance of it, so a C64 and an
# ANSI terminal paint on the same canvas.
class PixeliaBBS
  include BBS::Domain

  path    :data, 'data'
  setting :api_url, 'https://api.16colo.rs'
  setting :site_url, 'https://16colo.rs'
  setting :api_ttl, 3600
  setting :max_file_kb, 512
  setting :cache_mb, 100
  setting :max_rows, 1000
  setting :paint_rate, 20
  setting :wall_cooldown, 300
  setting :wall_per_hour, 30

  service(:gallery) do
    GalleryService.new(remote: SixteenColorsRepository.new(api_url: api_url, site_url: site_url, ttl: api_ttl,
                                                           max_bytes: max_file_kb * 1024),
                       cache: ArtCacheRepository.new(File.join(data, 'cache'), max_bytes: cache_mb * 1024 * 1024),
                       renderer: AnsiRenderService.new(max_rows: max_rows))
  end
  service(:canvas) { CanvasService.new(canvas_repository, rate: paint_rate) }
  service(:wall) do
    WallService.new(WorkRepository.new(File.join(data, 'works')), canvas: canvas, cooldown: wall_cooldown,
                                                                  per_hour: wall_per_hour)
  end

  # The canvas on disk; the admin scripts (bin/canvas) read it without a
  # running board.
  def canvas_repository
    @canvas_repository ||= CanvasRepository.new(File.join(data, 'canvas.json'), archive_dir: File.join(data, 'archive'),
                                                                                 clear_flag: File.join(data, 'canvas.clear'))
  end

  def start
    canvas_repository.start
    super
  end
end
