# frozen_string_literal: true

# The Wall: the canvas saved as a work under a title and a handle, the works
# newest first, and their removal (the admin script's moderation). A caller
# (Rubbs::Common::Line::RateLimit.caller_key: an address, not a session, so calling again
# does not help) saves at most once in +cooldown+ seconds, and the whole
# board at most +per_hour+ times an hour. Both limits are checked together
# and a save counts in both only once it is on the wall, so a failed write
# costs no turn.
class WallService
  MAX_TITLE  = 32
  MAX_HANDLE = 16
  BOARD      = :board

  def initialize(works, canvas:, cooldown: 300, per_hour: 30)
    @works   = works
    @canvas  = canvas
    @callers = Rubbs::Common::Line::RateLimit.new(limit: 1, per: cooldown)
    @board   = Rubbs::Common::Line::RateLimit.new(limit: per_hour, per: 3600)
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
  def clean(text, max) = Rubbs::Common::Text.line(text).gsub(/\p{Cf}/, '').squeeze(' ').strip[0, max].strip

  private

  # Under the lock, so that no other save comes between the check and the
  # count.
  def add(key, title, handle, canvas)
    limits = [[@callers, key], [@board, BOARD]]
    return :too_soon unless limits.all? { |limit, k| limit.room?(k) }

    work = @works.add(title: title, handle: handle, canvas: canvas) or return :failed
    limits.each { |limit, k| limit.record(k) }
    work
  end
end
