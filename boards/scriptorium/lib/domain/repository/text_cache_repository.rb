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
    BBS.log('text cache', "#{path}: #{e.class}: #{e.message}")
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
    BBS.log('text cache', "#{@dir}: #{e.class}: #{e.message}")
    nil
  end

  # The text of +chapter+ of book +id+ (UTF-8, without control characters:
  # a text cached by an older board may have them), or nil.
  def read(id, chapter)
    File.open(text_path(id), 'rb') do |f|
      f.seek(chapter.offset)
      BBS::Text.clean(f.read(chapter.length))
    end
  rescue SystemCallError => e
    BBS.log('text cache', "#{text_path(id)}: #{e.class}: #{e.message}")
    nil
  end

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
      books = cached_books.sort_by!(&:first)
      total = books.sum(&:last)
      while total > @max_bytes && books.size > 1
        _, json, txt, bytes = books.shift
        FileUtils.rm_f([json, txt])
        total -= bytes
      end
    end
  rescue SystemCallError => e
    BBS.log('text cache', "#{@dir}: #{e.class}: #{e.message}")
  end

  # Every cached book as [last read, index file, text file, bytes].
  def cached_books
    Dir.glob(File.join(@dir, '*.json')).map do |json|
      txt = json.sub(/\.json\z/, '.txt')
      [File.mtime(json), json, txt, File.size(json) + (File.exist?(txt) ? File.size(txt) : 0)]
    end
  end
end
