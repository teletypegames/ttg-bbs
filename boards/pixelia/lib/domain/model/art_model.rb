# frozen_string_literal: true

# A piece of text art rendered into a grid of cells: per row the characters
# (Unicode) and the foreground and background colours (0-15, the CGA/ANSI
# order: 0 black, 1 red … 7 light grey, 8 dark grey … 15 white). The rows are
# packed (a String of characters, two binary Strings of colour bytes), so a
# long piece stays small. Also its SAUCE record, if it has one.
class ArtModel
  # One row: +chars+ a String of +width+ characters, +fg+ and +bg+ binary
  # Strings of +width+ colour bytes.
  Row = Struct.new(:chars, :fg, :bg)

  attr_reader :width, :rows, :sauce

  def initialize(width:, rows:, sauce: nil, truncated: false)
    @width     = width
    @rows      = rows.freeze
    @sauce     = sauce
    @truncated = truncated
    freeze
  end

  def height = @rows.size

  # True when the piece was cut at the row or byte limit.
  def truncated? = @truncated

  # The cells of row +y+ from column +x+, +count+ of them, as
  # [[char, fg, bg], …]; blank cells past the edges.
  def cells(y, x = 0, count = @width)
    row = @rows[y]
    return Array.new(count) { [' ', 7, 0] } unless row

    chars = row.chars.each_char.to_a
    Array.new(count) do |i|
      col = x + i
      col < @width && col >= 0 ? [chars[col], row.fg.getbyte(col), row.bg.getbyte(col)] : [' ', 7, 0]
    end
  end
end
