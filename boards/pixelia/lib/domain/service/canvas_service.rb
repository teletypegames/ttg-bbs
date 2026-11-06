# frozen_string_literal: true

# The rules of the shared canvas: what a cell may hold (GlyphModel), how a
# colour lands in it (ink on black, or black on ink when reversed: one colour
# a cell, as on a C64), how fast one caller may paint (+rate+ cells a second,
# a bucket of as many), the undo of a caller's own last cells, and who is on
# the canvas now (seen in the last PRESENCE seconds).
class CanvasService
  PRESENCE   = 15
  UNDO_DEPTH = 64
  FORGET     = 3600

  Painter = Struct.new(:tokens, :refilled, :seen, :undo)

  def initialize(repository, rate: 20)
    @repository = repository
    @rate       = rate.to_f
    @painters   = {}
    @lock       = Mutex.new
  end

  def snapshot = @repository.snapshot

  def cols = CanvasModel::COLS

  def rows = CanvasModel::ROWS

  # The cell a paint of +char+ in +color+ makes, [char, fg, bg]; nil when
  # the canvas does not take +char+.
  def self.cell(char, color, reverse)
    char = GlyphModel.normalize(char)
    return nil unless char

    color = color.to_i.clamp(0, ColorModel.count - 1)
    return [CanvasModel::BLANK, 0, 0] if char == CanvasModel::BLANK && !reverse
    return [char, 0, 0] if color.zero?

    reverse ? [char, 0, color] : [char, color, 0]
  end

  # Paints +char+ at +x+, +y+ for the caller +who+ (a session id): :ok,
  # :too_fast, :bad_glyph or :outside.
  def paint(who, x, y, char, color, reverse: false)
    return :outside unless CanvasModel.inside?(x, y)

    cell = self.class.cell(char, color, reverse)
    return :bad_glyph unless cell
    return :too_fast unless take_token(who)

    index  = CanvasModel.index(x, y)
    before = @repository.put(index, *cell)
    remember(who, index, before, cell) if before && before != cell
    :ok
  end

  # Clears the cell at +x+, +y+ (a blank on black).
  def erase(who, x, y) = paint(who, x, y, CanvasModel::BLANK, 0)

  # Puts back the cell the caller +who+ changed last, while nobody painted
  # over it since: :ok, or :nothing when there is nothing left to undo.
  def undo(who)
    loop do
      step = @lock.synchronize { painter(who).undo.pop }
      return :nothing unless step

      index, before, after = step
      return :ok if @repository.put(index, *before, expect: after)
    end
  end

  # Marks +who+ as on the canvas now.
  def touch(who) = @lock.synchronize { painter(who).seen = now }

  # Takes +who+ off the canvas.
  def leave(who) = @lock.synchronize { @painters[who]&.seen = nil }

  # How many callers are on the canvas now, +who+ among them if there.
  def painters
    @lock.synchronize do
      t = now
      @painters.delete_if { |_, p| p.seen.nil? && t - p.refilled > FORGET }
      @painters.count { |_, p| p.seen && t - p.seen < PRESENCE }
    end
  end

  private

  def painter(who) = (@painters[who] ||= Painter.new(@rate, now, nil, []))

  def take_token(who)
    @lock.synchronize do
      p = painter(who)
      t = now
      p.tokens   = [p.tokens + ((t - p.refilled) * @rate), @rate].min
      p.refilled = t
      p.seen     = t
      return false if p.tokens < 1

      p.tokens -= 1
      true
    end
  end

  def remember(who, index, before, after)
    @lock.synchronize do
      stack = painter(who).undo
      stack << [index, before, after]
      stack.shift while stack.size > UNDO_DEPTH
    end
  end

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
