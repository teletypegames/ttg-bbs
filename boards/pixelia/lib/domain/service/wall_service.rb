# frozen_string_literal: true

# The Wall: the canvas saved as a work under a title and a handle, the works
# newest first, and their removal (the admin script's moderation). A caller
# (BBS::RateLimit.caller_key: an address, not a session, so calling again
# does not help) saves at most once in +cooldown+ seconds, and the whole
# board at most +per_hour+ times an hour.
class WallService
  MAX_TITLE  = 32
  MAX_HANDLE = 16
  BOARD      = :board

  def initialize(works, canvas:, cooldown: 300, per_hour: 30)
    @works   = works
    @canvas  = canvas
    @callers = BBS::RateLimit.new(limit: 1, per: cooldown)
    @board   = BBS::RateLimit.new(limit: per_hour, per: 3600)
    @lock    = Mutex.new
  end

  def all = @works.all

  def find(id) = @works.find(id)

  def remove(id) = @works.remove(id)

  # Saves the canvas as it is now for the caller +key+: the WorkModel, or
  # :no_title, :no_handle, :blank_canvas, :too_soon or :failed.
  def save(key, title:, handle:)
    title  = clean(title, MAX_TITLE)
    handle = clean(handle, MAX_HANDLE)
    return :no_title if title.empty?
    return :no_handle if handle.empty?

    canvas = @canvas.snapshot
    return :blank_canvas if canvas.empty?

    @lock.synchronize { add(key, title, handle, canvas) }
  end

  # Seconds until the caller +key+ may save again; 0 when now.
  def wait(key) = [@callers.wait(key), @board.wait(BOARD)].max.ceil

  # +text+ on one line without control or invisible format characters, its
  # spaces squeezed, at most +max+ characters long.
  def clean(text, max)
    BBS::Text.clean(text, keep_newlines: false).gsub(/\p{Cf}/, '').tr("\t", ' ').squeeze(' ').strip[0, max].strip
  end

  private

  def add(key, title, handle, canvas)
    return :too_soon if wait(key).positive?

    work = @works.add(title: title, handle: handle, canvas: canvas)
    return :failed unless work

    @callers.allow?(key)
    @board.allow?(BOARD)
    work
  end
end
