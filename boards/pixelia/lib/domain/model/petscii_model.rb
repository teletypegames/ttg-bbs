# frozen_string_literal: true

# A PETSCII work on the Exhibition, frozen: a C64 screen as TTG Canvas 64
# saves it (TcvModel), 40×25 screen codes (bit 7 reverse) and a colour per
# cell (0-15, any of them), the border and background colour and one of the
# ROM character sets: +:upper+ (upper case / graphics) or +:lower+ (lower /
# upper case). Its JSON keeps the screen codes as two hex digits a cell and
# the colours as one, a row a string.
class PetsciiModel
  COLS     = 40
  ROWS     = 25
  SIZE     = COLS * ROWS
  CHARSETS = %i[upper lower].freeze
  # The screen codes of a space: the space and the shifted space.
  SPACES   = [0x20, 0x60].freeze
  REVERSE  = 0x80

  attr_reader :charset, :border, :background, :screen, :colors

  def initialize(charset:, border:, background:, screen:, colors:)
    raise ArgumentError, 'not a PETSCII screen' unless CHARSETS.include?(charset) && screen.size == SIZE && colors.size == SIZE

    @charset    = charset
    @border     = border & 0x0f
    @background = background & 0x0f
    @screen     = screen.map { |c| c & 0xff }.freeze
    @colors     = colors.map { |c| c & 0x0f }.freeze
    freeze
  end

  # The work of a hires TcvModel with a ROM character set.
  def self.from_tcv(tcv)
    new(
      charset:    tcv.charset == TcvModel::ROM_LOWER ? :lower : :upper,
      border:     tcv.border,
      background: tcv.background,
      screen:     tcv.screen,
      colors:     tcv.colors
    )
  end

  # The cell at +x+, +y+: [screen code, colour].
  def at(x, y)
    i = (y * COLS) + x
    [@screen[i], @colors[i]]
  end

  # True when no cell shows anything but the background.
  def empty? = SIZE.times.none? { |i| visible?(@screen[i], @colors[i]) }

  def visible?(code, color) = color != @background && !(code < REVERSE && SPACES.include?(code))

  # The PETSCII code that prints the screen code +code+ (its reverse bit
  # left out) through the C64's CHROUT.
  def self.petscii(code)
    base = code & 0x7f
    case base
    when 0x00..0x1f, 0x60..0x7f then base + 0x40
    when 0x40..0x5f then base + 0x80
    else base
    end
  end

  def to_h
    {
      'charset'    => @charset.to_s,
      'border'     => @border,
      'background' => @background,
      'screen'     => ROWS.times.map { |y| @screen[y * COLS, COLS].map { |c| format('%02x', c) }.join },
      'color'      => ROWS.times.map { |y| @colors[y * COLS, COLS].map { |c| c.to_s(16) }.join }
    }
  end

  # A work from its JSON Hash; nil when it is not one.
  def self.from_h(hash)
    return nil unless hash.is_a?(Hash) && CHARSETS.map(&:to_s).include?(hash['charset'])

    screen = cells(hash['screen'], 2)
    colors = cells(hash['color'], 1)
    return nil unless screen && colors && [hash['border'], hash['background']].all?(Integer)

    new(charset: hash['charset'].to_sym, border: hash['border'], background: hash['background'], screen: screen, colors: colors)
  end

  # The cells of +rows+ (ROWS strings of hex, +digits+ a cell); nil when they
  # are not that.
  def self.cells(rows, digits)
    return nil unless rows.is_a?(Array) && rows.size == ROWS
    return nil unless rows.all? { |row| row.is_a?(String) && row.match?(/\A\h{#{COLS * digits}}\z/) }

    rows.flat_map { |row| row.scan(/\h{#{digits}}/).map(&:hex) }
  end
  private_class_method :cells
end
