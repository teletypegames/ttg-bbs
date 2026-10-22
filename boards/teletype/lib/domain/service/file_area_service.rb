# frozen_string_literal: true

# The file areas of the old boards over the catalog: one area per
# platform, a file per downloadable asset of each game's latest release,
# with its size from the FTP server's WARP folder and the release's
# download count. Web builds are folders on the server; their zip is the
# file here.
class FileAreaService
  Area     = Struct.new(:platform, :title, :files)
  FileItem = Struct.new(:name, :path, :bytes, :date, :downloads, :game, :kind, keyword_init: true)

  NEW_DAYS = 30

  def initialize(games:, files:)
    @games = games
    @files = files
  end

  def areas
    warp = (@files.list('/WARP') || []).to_h { |e| [e.name, e] }
    @games.all.reject { |g| g.dev_build? || !g.released? }
          .group_by(&:platform)
          .map { |platform, games| Area.new(platform, GamesService.platform_name(platform), files_of(games, warp)) }
          .reject { |a| a.files.empty? }
          .sort_by(&:title)
  end

  def new?(item) = item.date && item.date > Time.now - (NEW_DAYS * 86_400)

  # The FTP entry of a file, for the FTP Browser's ZMODEM download.
  def entry(item) = FtpEntry.new(name: item.name, path: item.path, bytes: item.bytes, modified: item.date, dir: false)

  private

  def files_of(games, warp)
    games.sort_by { |g| g.title.downcase }.flat_map do |game|
      release = game.releases.last
      game.assets.filter_map do |asset|
        name  = File.basename(asset.path)
        name  = "#{name}.html.zip" if asset.kind == 'html'
        found = warp[name]
        next unless found && !found.dir

        FileItem.new(name: name, path: "/WARP/#{name}", bytes: found.bytes, date: game.released_at,
                     downloads: release&.downloads.to_i, game: game, kind: asset.kind)
      end
    end
  end
end
