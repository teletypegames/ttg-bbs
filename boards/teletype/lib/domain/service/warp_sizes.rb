# frozen_string_literal: true

# The size of each catalog file, from the WARP folder of the FTP server,
# where every file of every release lies. The catalog API does not carry
# sizes; the Commodore doors need them for the blocks of their disk.
class WarpSizes
  FOLDER = '/WARP'

  def initialize(repo) = @repo = repo

  # The size in bytes of a file at the top of WARP, nil when it is not
  # there or the FTP server did not answer.
  def of(name) = Remote.read('ftp', nil) { @repo.sizes(FOLDER) }&.[](name)
end
