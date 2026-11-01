# frozen_string_literal: true

require 'fileutils'
require 'json'

# The books already fetched, on disk (data/texts): <id>.txt is the cleaned
# text, <id>.json its chapter index. A chapter is read from the file when it
# is shown, so no session keeps a whole book. The folder is kept under
# +max_bytes+: the books read least recently go first (the index file's
# mtime is touched on every open).
class TextCacheRepository
  def initialize(dir, max_bytes:)
    @dir       = dir
    @max_bytes = max_bytes
    @lock      = Mutex.new
  end

  # The index of book +id+, or nil when it is not cached.
  def index(id)
    path = json_path(id)
    return nil unless File.exist?(path) && File.exist?(text_path(id))

    text = TextModel.from_h(JSON.parse(File.read(path)))
    touch(path) if text
    text
  rescue JSON::ParserError, SystemCallError => e
    warn "scriptorium-bbs: #{path}: #{e.class}: #{e.message}"
    nil
  end

  # Saves the cleaned +text+ of book +id+ with its +chapters+
  # ([title, offset, length]) and returns the TextModel; nil when the disk
  # refuses.
  def store(id, text, chapters)
    model = TextModel.from_h('book_id' => id, 'bytes' => text.bytesize, 'chapters' => chapters)
    @lock.synchronize do
      FileUtils.mkdir_p(@dir)
      write(text_path(id), text)
      write(json_path(id), JSON.generate(model.to_h))
    end
    evict
    model
  rescue SystemCallError => e
    warn "scriptorium-bbs: #{@dir}: #{e.class}: #{e.message}"
    nil
  end

  # The text of +chapter+ of book +id+ (UTF-8), or nil.
  def read(id, chapter)
    File.open(text_path(id), 'rb') do |f|
      f.seek(chapter.offset)
      f.read(chapter.length).to_s.force_encoding(Encoding::UTF_8).scrub
    end
  rescue SystemCallError => e
    warn "scriptorium-bbs: #{text_path(id)}: #{e.class}: #{e.message}"
    nil
  end

  # The bytes the cache takes.
  def size = Dir.glob(File.join(@dir, '*.{txt,json}')).sum { |f| File.size(f) }

  private

  def text_path(id) = File.join(@dir, "#{Integer(id)}.txt")
  def json_path(id) = File.join(@dir, "#{Integer(id)}.json")

  def write(path, data)
    File.binwrite("#{path}.tmp", data)
    File.rename("#{path}.tmp", path)
  end

  def touch(path)
    now = Time.now
    File.utime(now, now, path)
  rescue SystemCallError
    nil
  end

  # Deletes the least recently read books until the folder fits.
  def evict
    @lock.synchronize do
      books = Dir.glob(File.join(@dir, '*.json')).map do |json|
        txt = json.sub(/\.json\z/, '.txt')
        [File.mtime(json), json, txt, File.size(json) + (File.exist?(txt) ? File.size(txt) : 0)]
      end
      total = books.sum(&:last)
      books.sort_by!(&:first)
      while total > @max_bytes && books.size > 1
        _, json, txt, bytes = books.shift
        FileUtils.rm_f([json, txt])
        total -= bytes
      end
    end
  rescue SystemCallError => e
    warn "scriptorium-bbs: #{@dir}: #{e.class}: #{e.message}"
  end
end
