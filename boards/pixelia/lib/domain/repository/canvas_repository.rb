# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'securerandom'
require 'time'

# The shared canvas: the cells in memory behind a Mutex, a version that
# grows with every change, and data/canvas.json on disk. Writes are
# debounced: a BBS.background thread writes the file (to a temporary file,
# then renamed) at most every +flush_seconds+, when something changed.
#
# The admin script asks for a clear by creating +clear_flag+: the thread
# archives the canvas into +archive_dir+, blanks it and removes the flag.
class CanvasRepository
  attr_reader :path

  def initialize(path, archive_dir:, clear_flag:, flush_seconds: 2)
    @path          = path
    @archive_dir   = archive_dir
    @clear_flag    = clear_flag
    @flush_seconds = flush_seconds
    @lock          = Mutex.new
    @dirty         = false
    @version       = 0
    @snapshot      = nil
    load
  end

  # The canvas as it is now, a CanvasModel (the same object until it changes).
  def snapshot
    @lock.synchronize do
      @snapshot ||= CanvasModel.new(@chars, @fg, @bg, version: @version)
    end
  end

  def version = @lock.synchronize { @version }

  # Sets the cell at +index+ and returns what it held, [char, fg, bg]. With
  # +expect+ the cell changes only while it still holds that, and the result
  # is nil when it does not.
  def put(index, char, fg, bg, expect: nil)
    @lock.synchronize do
      before = [@chars[index], @fg[index], @bg[index]]
      return nil if expect && before != expect
      return before if before == [char, fg, bg]

      @chars[index] = char
      @fg[index]    = fg
      @bg[index]    = bg
      changed!
      before
    end
  end

  # Archives the canvas as it is and blanks it. Returns the archive's path,
  # or nil when it could not be written (then the canvas stays).
  def clear
    @lock.synchronize do
      archived = archive
      return nil unless archived

      assign(CanvasModel.blank)
      changed!
      write
      archived
    end
  end

  # Writes the file when something changed since the last write.
  def flush
    @lock.synchronize { write if @dirty }
  end

  # Starts the thread that writes the file and answers the clear flag every
  # +flush_seconds+; an error is logged and the next round comes as usual.
  def start
    BBS.background('canvas writer', every: @flush_seconds, retry_after: @flush_seconds,
                                    max_retry: @flush_seconds) { tick }
    at_exit { flush }
    self
  end

  # One round of the writer: the clear the admin asked for, then the file.
  def tick
    if File.exist?(@clear_flag)
      clear
      FileUtils.rm_f(@clear_flag)
    end
    flush
  end

  private

  def changed!
    @version += 1
    @snapshot = nil
    @dirty = true
  end

  def load
    canvas = File.exist?(@path) ? CanvasModel.from_h(JSON.parse(File.read(@path))) : nil
    BBS.log('canvas', "#{@path} is not a canvas, starting blank") if canvas.nil? && File.exist?(@path)
    assign(canvas || CanvasModel.blank)
  rescue SystemCallError, JSON::ParserError => e
    BBS.log('canvas', "#{@path}: #{e.class}: #{e.message}")
    assign(CanvasModel.blank)
  end

  def assign(canvas)
    @chars = canvas.chars.dup
    @fg    = canvas.fg.dup
    @bg    = canvas.bg.dup
  end

  def write
    save(@path)
    @dirty = false
  rescue SystemCallError => e
    BBS.log('canvas', "#{@path}: #{e.class}: #{e.message}")
  end

  def archive
    FileUtils.mkdir_p(@archive_dir)
    save(File.join(@archive_dir, "canvas-#{Time.now.strftime('%Y%m%d-%H%M%S')}-#{SecureRandom.hex(2)}.json"))
  rescue SystemCallError => e
    BBS.log('canvas', "#{@archive_dir}: #{e.class}: #{e.message}")
    nil
  end

  # Writes the canvas to +target+ whole or not at all: a temporary file of
  # its own (the board and the admin script may both write), then a rename.
  # Returns +target+.
  def save(target)
    FileUtils.mkdir_p(File.dirname(target))
    tmp = "#{target}.#{SecureRandom.hex(4)}.tmp"
    File.write(tmp, JSON.generate(CanvasModel.new(@chars, @fg, @bg).to_h))
    File.rename(tmp, target)
    target
  ensure
    FileUtils.rm_f(tmp) if tmp
  end
end
