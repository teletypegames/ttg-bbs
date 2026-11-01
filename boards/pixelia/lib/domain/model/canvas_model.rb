# frozen_string_literal: true

# A 40×25 picture of the canvas, frozen: a character and two C64 colours
# (ColorModel indexes) per cell. A cell has at most one colour that is not
# black, the way a C64 shows it: ink on black, or black on ink (reverse).
# It reads and writes the JSON of data/canvas.json and of a work on the Wall:
# the rows as strings, the colours as one hex digit a cell.
class CanvasModel
  COLS = 40
  ROWS = 25
  SIZE = COLS * ROWS
  BLANK = ' '

  attr_reader :chars, :fg, :bg, :version

  def initialize(chars, fg, bg, version: 0)
    @chars   = chars.dup.freeze
    @fg      = fg.dup.freeze
    @bg      = bg.dup.freeze
    @version = version
    freeze
  end

  def self.blank = new(Array.new(SIZE, BLANK), Array.new(SIZE, 0), Array.new(SIZE, 0))

  def self.index(x, y) = (y * COLS) + x

  def self.inside?(x, y) = x.between?(0, COLS - 1) && y.between?(0, ROWS - 1)

  # The cell at +x+, +y+: [char, fg, bg].
  def at(x, y)
    i = self.class.index(x, y)
    [@chars[i], @fg[i], @bg[i]]
  end

  # True when no cell shows anything: blank, or drawn in black on black.
  def empty? = SIZE.times.none? { |i| visible?(i) }

  def visible?(index) = @bg[index].positive? || (@chars[index] != BLANK && @fg[index].positive?)

  def painted_cells = SIZE.times.count { |i| visible?(i) }

  def to_h
    { 'cols' => COLS, 'rows' => ROWS,
      'chars' => ROWS.times.map { |y| @chars[y * COLS, COLS].join },
      'fg' => ROWS.times.map { |y| @fg[y * COLS, COLS].map { |c| c.to_s(16) }.join },
      'bg' => ROWS.times.map { |y| @bg[y * COLS, COLS].map { |c| c.to_s(16) }.join } }
  end

  # A canvas from its JSON Hash; nil when it is not one.
  def self.from_h(hash, version: 0)
    return nil unless hash.is_a?(Hash)

    chars = rows(hash['chars']) { |row| row.each_char.to_a }
    fg    = rows(hash['fg']) { |row| row.each_char.map { |c| c.to_i(16) } }
    bg    = rows(hash['bg']) { |row| row.each_char.map { |c| c.to_i(16) } }
    return nil unless chars && fg && bg

    new(chars, fg, bg, version: version)
  end

  def self.rows(list)
    return nil unless list.is_a?(Array) && list.size == ROWS

    cells = list.flat_map do |row|
      row = row.to_s
      out = yield(row)
      return nil unless out.size == COLS

      out
    end
    cells.size == SIZE ? cells : nil
  end
end
