# frozen_string_literal: true

require 'fileutils'

# The texts of the RFCs on disk, data/rfc/rfc<N>.txt, as the RFC Editor
# published them: the layout of its rsync module rfcs-text-only, so a mirror
# fills the same folder. An RFC never changes, so nothing here expires.
class TextRepository
  def initialize(dir)
    @dir = dir
  end

  def path(number) = File.join(@dir, "rfc#{Integer(number)}.txt")

  def exist?(number) = File.exist?(path(number))

  # The text of RFC +number+ as UTF-8 (an invalid byte becomes "?"), or nil
  # when it is not here.
  def read(number)
    File.binread(path(number)).force_encoding(Encoding::UTF_8).scrub('?')
  rescue Errno::ENOENT
    nil
  rescue SystemCallError => e
    BBS.log('texts', "#{path(number)}: #{e.class}: #{e.message}")
    nil
  end

  # Keeps +bytes+ as the text of RFC +number+; false when the disk refuses.
  def store(number, bytes)
    FileUtils.mkdir_p(@dir)
    File.binwrite("#{path(number)}.tmp", bytes)
    File.rename("#{path(number)}.tmp", path(number))
    true
  rescue SystemCallError => e
    BBS.log('texts', "#{path(number)}: #{e.class}: #{e.message}")
    false
  end

  # How many texts are here.
  def count = Dir.glob(File.join(@dir, 'rfc*.txt')).size
end
