# frozen_string_literal: true

# The Wall: the canvas saved as a work under a title and a handle, the works
# newest first, and their removal (the admin script's moderation). A caller
# saves at most once in +cooldown+ seconds.
class WallService
  MAX_TITLE  = 32
  MAX_HANDLE = 16

  def initialize(works, canvas:, cooldown: 300)
    @works    = works
    @canvas   = canvas
    @cooldown = cooldown
    @saved    = {}
    @lock     = Mutex.new
  end

  def all = @works.all

  def find(id) = @works.find(id)

  def remove(id) = @works.remove(id)

  # Saves the canvas as it is now for the caller +who+: the WorkModel, or
  # :no_title, :no_handle, :blank_canvas, :too_soon or :failed.
  def save(who, title:, handle:)
    title  = clean(title, MAX_TITLE)
    handle = clean(handle, MAX_HANDLE)
    return :no_title if title.empty?
    return :no_handle if handle.empty?

    canvas = @canvas.snapshot
    return :blank_canvas if canvas.empty?
    return :too_soon if wait(who).positive?

    work = @works.add(title: title, handle: handle, canvas: canvas)
    return :failed unless work

    @lock.synchronize { @saved[who] = now }
    work
  end

  # Seconds until +who+ may save again; 0 when now.
  def wait(who)
    at = @lock.synchronize { @saved[who] }
    at ? [(@cooldown - (now - at)).ceil, 0].max : 0
  end

  # +text+ without control characters, its spaces squeezed, at most +max+
  # characters long.
  def clean(text, max) = text.to_s.scrub('').gsub(/[\p{Cc}\p{Cf}]/, '').squeeze(' ').strip[0, max].to_s.strip

  private

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
