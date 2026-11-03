# frozen_string_literal: true

require 'fileutils'

# The texts of the RFCs on disk, data/rfc/rfc<N>.txt, as the RFC Editor
# published them: the layout of its rsync module rfcs-text-only, so the
# mirror (MirrorService) fills the same folder. An IEN (a negative number)
# is ien<N>.txt beside them. An RFC never changes, so nothing here expires.
class TextRepository
  def initialize(dir)
    @dir = dir
  end

  attr_reader :dir

  def path(number)
    number = Integer(number)
    File.join(@dir, number.negative? ? "ien#{-number}.txt" : "rfc#{number}.txt")
  end

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

  # How many texts of RFCs are here.
  def count = Dir.glob(File.join(@dir, 'rfc*.txt')).size

  # The numbers of the texts here, an IEN's negative, with their size and
  # mtime: { 854 => [57_000, 1700000000], -137 => [...] }.
  def stats
    Dir.glob(File.join(@dir, '{rfc,ien}*.txt')).each_with_object({}) do |path, out|
      m = /\A(rfc|ien)(\d+)\.txt\z/.match(File.basename(path)) or next
      st = File.stat(path)
      out[m[1] == 'ien' ? -m[2].to_i : m[2].to_i] = [st.size, st.mtime.to_i]
    end
  end
end
