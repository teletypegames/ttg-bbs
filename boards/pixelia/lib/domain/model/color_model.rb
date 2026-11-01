# frozen_string_literal: true

# One of the sixteen colours of the Commodore 64, the palette of the canvas:
# its index in the C64's order (0 black … 15 light grey), its name, the
# nearest of the 16 ANSI colours and an xterm-256 colour picked by hand from
# the Colodore palette, so that all sixteen stay apart on a modern terminal.
class ColorModel
  # Index, name, ANSI colour (0-15) and xterm-256 colour of every C64 colour.
  TABLE = [
    [0,  'black',       0,  16],  [1,  'white',       15, 231],
    [2,  'red',         1,  88],  [3,  'cyan',        6,  80],
    [4,  'purple',      5,  91],  [5,  'green',       2,  71],
    [6,  'blue',        4,  19],  [7,  'yellow',      11, 227],
    [8,  'orange',      3,  130], [9,  'brown',       3,  58],
    [10, 'light red',   9,  167], [11, 'dark grey',   8,  238],
    [12, 'grey',        8,  243], [13, 'light green', 10, 156],
    [14, 'light blue',  12, 63],  [15, 'light grey',  7,  249]
  ].freeze

  attr_reader :index, :name, :ansi, :xterm

  def initialize(index, name, ansi, xterm)
    @index = index
    @name  = name
    @ansi  = ansi
    @xterm = xterm
    freeze
  end

  def black? = @index.zero?

  ALL = TABLE.map { |row| new(*row) }.freeze

  def self.all = ALL

  def self.[](index) = ALL[index.to_i % ALL.size]

  def self.count = ALL.size
end
