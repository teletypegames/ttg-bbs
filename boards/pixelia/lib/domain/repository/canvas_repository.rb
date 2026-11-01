# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'time'

# The shared canvas: the cells in memory behind a Mutex, a version that
# grows with every change, and data/canvas.json on disk. Writes are
# debounced: a thread writes the file (to a temporary file, then renamed) at
# most every +flush_seconds+, when something changed.
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

      blank = CanvasModel.blank
      @chars = blank.chars.dup
      @fg    = blank.fg.dup
      @bg    = blank.bg.dup
      changed!
      write
      archived
    end
  end

  # Writes the file when something changed since the last write.
  def flush
    @lock.synchronize { write if @dirty }
  end

  # Starts the thread that writes the file and answers the clear flag.
  def start
    Thread.new do
      loop do
        sleep @flush_seconds
        if File.exist?(@clear_flag)
          clear
          FileUtils.rm_f(@clear_flag)
        end
        flush
      rescue StandardError => e
        warn "pixelia-bbs: canvas writer: #{e.class}: #{e.message}"
      end
    end
    at_exit { flush }
    self
  end

  private

  def changed!
    @version += 1
    @snapshot = nil
    @dirty = true
  end

  def load
    canvas = File.exist?(@path) ? CanvasModel.from_h(JSON.parse(File.read(@path))) : nil
    warn "pixelia-bbs: #{@path} is not a canvas, starting blank" if canvas.nil? && File.exist?(@path)
    canvas ||= CanvasModel.blank
    @chars = canvas.chars.dup
    @fg    = canvas.fg.dup
    @bg    = canvas.bg.dup
  rescue SystemCallError, JSON::ParserError => e
    warn "pixelia-bbs: #{@path}: #{e.class}: #{e.message}"
    blank = CanvasModel.blank
    @chars = blank.chars.dup
    @fg    = blank.fg.dup
    @bg    = blank.bg.dup
  end

  def write
    FileUtils.mkdir_p(File.dirname(@path))
    tmp = "#{@path}.tmp"
    File.write(tmp, JSON.generate(CanvasModel.new(@chars, @fg, @bg).to_h))
    File.rename(tmp, @path)
    @dirty = false
  rescue SystemCallError => e
    warn "pixelia-bbs: #{@path}: #{e.class}: #{e.message}"
  end

  def archive
    FileUtils.mkdir_p(@archive_dir)
    target = File.join(@archive_dir, "canvas-#{Time.now.strftime('%Y%m%d-%H%M%S')}.json")
    File.write(target, JSON.generate(CanvasModel.new(@chars, @fg, @bg).to_h))
    target
  rescue SystemCallError => e
    warn "pixelia-bbs: #{@archive_dir}: #{e.class}: #{e.message}"
    nil
  end
end
