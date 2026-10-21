# frozen_string_literal: true

# The ANSI art of the desktop: the files of one folder, a gallery to browse
# them, and a favourite per registered name, kept in the profile.
class ArtService
  EXTENSIONS = %w[.ans .ansi .asc .nfo .txt].freeze

  # +source+ is a folder of art, or one file (its folder is the gallery and
  # the file is the default desktop).
  def initialize(source, profile:)
    @dir     = File.directory?(source) ? source : File.dirname(source)
    @default = File.file?(source) ? File.basename(source) : nil
    @profile = profile
  end

  def files
    Dir.children(@dir).select { |f| EXTENSIONS.include?(File.extname(f).downcase) && File.file?(path(f)) }.sort
  rescue SystemCallError
    []
  end

  def path(name) = File.join(@dir, File.basename(name))
  def lines(name) = BBS::Widgets::AnsiArt.load_file(path(name))
  def sauce(name) = BBS::Widgets::AnsiArt.sauce(path(name))
  def size(name) = File.size(path(name))

  def favourite(username)
    name = @profile.find(username.to_s)&.fetch('art', nil).to_s
    files.include?(name) ? name : nil
  end

  def set_favourite(username, name) = @profile.update(username, art: name)

  # The art a session starts with: the caller's favourite, else the
  # configured file, else a random one of the folder.
  def for_caller(username)
    favourite(username) || (@default if files.include?(@default)) || files.sample
  end
end
