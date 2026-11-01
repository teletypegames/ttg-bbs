# frozen_string_literal: true

# Renders the bytes of an ANSI or ASCII art file into an ArtModel, the way
# ANSI.SYS put it on a DOS screen: CP437 characters, SGR colours (bold is a
# bright foreground; blink a bright background when the SAUCE record asks for
# iCE colours), the cursor moves (CUU CUD CUF CUB CUP, save and restore), the
# erases (ED, EL), TAB, CR and LF, and the line wrapping at the width of the
# SAUCE record or 80. Everything from the first SUB byte (\x1A) on, the SAUCE
# record among it, is not art.
#
# Malformed input does not raise: an unknown sequence is skipped, a cursor
# move is clamped. A huge file is cut at +max_bytes+ and +max_rows+.
class AnsiRenderService
  DEFAULT_WIDTH = 80
  MAX_WIDTH     = 160
  DEFAULT_FG    = 7
  DEFAULT_BG    = 0
  TAB           = 8
  MAX_PARAMS    = 32

  ESC = 0x1b
  SUB = 0x1a
  CR  = 0x0d
  LF  = 0x0a
  HT  = 0x09
  BS  = 0x08
  NUL = 0x00
  BEL = 0x07
  CSI = 0x5b

  # The CP437 glyphs of the control codes, which DOS shows as pictures.
  LOW = ' ☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼'
  CP437 = Array.new(256) do |b|
    if b < 0x20 then LOW[b]
    elsif b < 0x7f then b.chr
    elsif b == 0x7f then '⌂'
    elsif b == 0xff then ' '
    else b.chr.force_encoding('IBM437').encode('UTF-8')
    end
  end.freeze

  def initialize(max_rows: 1000, max_bytes: 512 * 1024)
    @max_rows  = max_rows
    @max_bytes = max_bytes
  end

  # The ArtModel of +bytes+.
  def render(bytes)
    data  = bytes.to_s.b
    sauce = SauceModel.parse(data)
    sub   = data.index(SUB.chr)
    data  = data.byteslice(0, sub) if sub
    truncated = data.bytesize > @max_bytes
    data = data.byteslice(0, @max_bytes) if truncated
    width = (sauce&.width || DEFAULT_WIDTH).clamp(1, MAX_WIDTH)
    Parser.new(width, sauce&.ice? || false, @max_rows).run(data, sauce, truncated)
  end

  # One run over the bytes of a file: the cursor, the colours and the grid.
  class Parser
    def initialize(width, ice, max_rows)
      @width    = width
      @ice      = ice
      @max_rows = max_rows
      @grid     = {}
      @x        = 0
      @y        = 0
      @saved    = [0, 0]
      @cut      = false
      reset_colors
    end

    def run(data, sauce, truncated)
      i = 0
      size = data.bytesize
      while i < size && @y < @max_rows
        b = data.getbyte(i)
        i += 1
        case b
        when ESC then i = escape(data, i)
        when CR  then @x = 0
        when LF  then newline
        when HT  then @x = [((@x / TAB) + 1) * TAB, @width - 1].min
        when BS  then @x = [@x - 1, 0].max
        when NUL, BEL then nil
        else put(CP437[b])
        end
      end
      @cut = true if @y >= @max_rows
      ArtModel.new(width: @width, rows: rows, sauce: sauce, truncated: truncated || @cut)
    end

    private

    def reset_colors
      @fg      = DEFAULT_FG
      @bg      = DEFAULT_BG
      @bold    = false
      @blink   = false
      @reverse = false
    end

    def newline
      @x = 0
      @y += 1
    end

    def put(char)
      fg = @fg + (@bold ? 8 : 0)
      bg = @bg + (@blink && @ice ? 8 : 0)
      fg, bg = bg, fg if @reverse
      row = row(@y)
      row[0][@x] = char
      row[1][@x] = fg
      row[2][@x] = bg
      @x += 1
      newline if @x >= @width
    end

    def row(y) = (@grid[y] ||= [Array.new(@width, ' '), Array.new(@width, DEFAULT_FG), Array.new(@width, DEFAULT_BG)])

    # ESC [ params final; anything else after ESC is dropped.
    def escape(data, i)
      return i unless data.getbyte(i) == CSI

      j = i + 1
      j += 1 while j < data.bytesize && j - i <= MAX_PARAMS && !data.getbyte(j).between?(0x40, 0x7e)
      return j if j >= data.bytesize || j - i > MAX_PARAMS

      params = data.byteslice(i + 1, j - i - 1)
      csi(params, data.getbyte(j).chr)
      j + 1
    end

    def csi(params, final)
      return if params.start_with?('?', '=', '>', '!')

      nums = params.split(';').map { |p| p.to_i.clamp(0, 9999) }
      n = [nums.first.to_i, 1].max
      case final
      when 'm' then sgr(nums.empty? ? [0] : nums)
      when 'A' then @y = [@y - n, 0].max
      when 'B' then @y = [@y + n, @max_rows].min
      when 'C' then @x = [@x + n, @width - 1].min
      when 'D' then @x = [@x - n, 0].max
      when 'G' then @x = (n - 1).clamp(0, @width - 1)
      when 'H', 'f'
        @y = ([nums[0].to_i, 1].max - 1).clamp(0, @max_rows)
        @x = ([nums[1].to_i, 1].max - 1).clamp(0, @width - 1)
      when 's' then @saved = [@x, @y]
      when 'u' then @x, @y = @saved
      when 'J' then erase_display(nums.first.to_i)
      when 'K' then erase_line(nums.first.to_i)
      end
    end

    def sgr(codes)
      i = 0
      while i < codes.size
        c = codes[i]
        case c
        when 0 then reset_colors
        when 1 then @bold = true
        when 5, 6 then @blink = true
        when 7 then @reverse = true
        when 21, 22 then @bold = false
        when 25 then @blink = false
        when 27 then @reverse = false
        when 30..37 then @fg = c - 30
        when 39 then @fg = DEFAULT_FG
        when 40..47 then @bg = c - 40
        when 49 then @bg = DEFAULT_BG
        when 90..97 then @fg = c - 90; @bold = true
        when 100..107 then @bg = c - 100; @blink = @ice = true
        when 38, 48 then i += extended(c, codes[i + 1], codes[i + 2])
        end
        i += 1
      end
    end

    # 38;5;n and 48;5;n for n < 16 set a colour; other forms are skipped.
    def extended(code, kind, index)
      return 4 unless kind == 5
      return 2 unless index && index < 16

      if code == 38
        @fg = index % 8
        @bold = index >= 8
      else
        @bg = index % 8
        @blink = index >= 8
        @ice = true if @blink
      end
      2
    end

    def erase_display(mode)
      return unless mode == 2

      @grid.clear
      @x = 0
      @y = 0
    end

    def erase_line(mode)
      row = @grid[@y]
      return unless row

      range = case mode
              when 1 then 0..@x
              when 2 then 0...@width
              else @x...@width
              end
      range.each do |x|
        next if x >= @width

        row[0][x] = ' '
        row[1][x] = DEFAULT_FG
        row[2][x] = DEFAULT_BG
      end
    end

    # The rows from the top to the last one that holds anything.
    def rows
      last = @grid.keys.max || 0
      last -= 1 while last.positive? && blank?(@grid[last])
      (0..last).map do |y|
        chars, fg, bg = @grid[y] || [Array.new(@width, ' '), Array.new(@width, DEFAULT_FG), Array.new(@width, DEFAULT_BG)]
        ArtModel::Row.new(chars.join.freeze, fg.pack('C*').freeze, bg.pack('C*').freeze)
      end
    end

    def blank?(row) = row.nil? || (row[0].all?(' ') && row[2].all?(DEFAULT_BG))
  end
end
