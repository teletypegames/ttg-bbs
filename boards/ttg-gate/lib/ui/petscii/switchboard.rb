# frozen_string_literal: true

require_relative 'canvas'

module UI
  module Petscii
    # The gate's menu on a C64, drawn on a Canvas: TTG GATE in fat rainbow
    # letters with a checkered shadow and twinkling stars around it, then the
    # boards as candy buttons in their own colours, two by four on a page.
    # A page that is not full shows its empty places as free lines, so the
    # next board has somewhere to go; more than eight turn into pages.
    class Switchboard
      PER_PAGE = 8
      TILE_WIDTH = 18
      TILE_COLS  = [1, 21].freeze
      TILE_TOP   = 9
      NAME_WIDTH = TILE_WIDTH - 4

      LOGO_TOP  = 1
      LOGO_LEFT = 2
      # The letters, 4×5: # a block, a b c d the triangles ◢ ◣ ◥ ◤.
      FONT = {
        'T' => %w[#### .##. .##. .##. .##.],
        'G' => %w[a##b #... #.## #..# c##d],
        'A' => %w[a##b #..# #### #..# #..#],
        'E' => %w[#### #... ###. #... ####],
        ' ' => %w[.. .. .. .. ..]
      }.freeze
      FONT_GLYPHS = { '#' => '█', 'a' => '◢', 'b' => '◣', 'c' => '◥', 'd' => '◤' }.freeze
      RAINBOW = [Canvas::LIGHT_RED, Canvas::ORANGE, Canvas::YELLOW, Canvas::LIGHT_GREEN, Canvas::CYAN].freeze

      STAR_ROWS   = [0, 7].freeze
      STARS       = %w[● ○ ♦ ♥ ♠ ♣ ▚ ╳].freeze
      STAR_COLORS = [Canvas::WHITE, Canvas::YELLOW, Canvas::CYAN, Canvas::LIGHT_RED, Canvas::PURPLE,
                     Canvas::LIGHT_GREEN, Canvas::LIGHT_BLUE, Canvas::ORANGE].freeze
      STRIPE = [Canvas::RED, Canvas::ORANGE, Canvas::YELLOW, Canvas::GREEN, Canvas::CYAN, Canvas::LIGHT_BLUE,
                Canvas::PURPLE, Canvas::LIGHT_RED].freeze

      MOTTO     = '♥ ONE NUMBER ♦ EVERY BOARD ♥'
      INFO_ROW  = 22
      PAGES_ROW = 21
      HELP_ROW  = 24
      HELP       = 'CRSR+RETURN OR 1-8: DIAL   Q: HANG UP'
      HELP_PAGES = 'RETURN/1-8 DIAL  +/- PAGE  Q HANG UP'

      attr_reader :page, :index

      def initialize(boards, random: Random.new)
        @boards = boards
        @random = random
        @page   = 0
        @index  = 0
        @stars  = {}
      end

      def pages = [(@boards.size + PER_PAGE - 1) / PER_PAGE, 1].max

      def on_page = @boards[@page * PER_PAGE, PER_PAGE] || []

      def selected = on_page[@index]

      # The board of digit +n+ on this page, nil when that place is empty.
      def board_at(digit) = on_page[digit - 1]

      # The whole screen.
      def frame
        canvas = Canvas.new
        stars(canvas)
        logo(canvas)
        canvas.text(7, centre(MOTTO), MOTTO, Canvas::WHITE)
        stripe(canvas, 8)
        PER_PAGE.times { |slot| tile(canvas, slot) }
        page_dots(canvas)
        info(canvas)
        help = pages > 1 ? HELP_PAGES : HELP
        canvas.text(HELP_ROW, centre(help), help, Canvas::GREY)
        canvas.frame + rest
      end

      # Moves the selection by +dx+ tiles across and +dy+ down; past the first
      # or the last row it turns the page. Returns the bytes that repaint
      # what changed: the hearts, the info, or the whole screen for a page.
      def move(dx, dy)
        slot = @index + dx + (dy * 2)
        if slot.negative? && @page.positive?
          @page -= 1
          @index = on_page.size - 1
          frame
        elsif slot >= on_page.size && @page < pages - 1
          @page += 1
          @index = 0
          frame
        else
          select(slot.clamp(0, on_page.size - 1))
        end
      end

      # Turns to the page +delta+ away; the whole screen, or nothing when
      # there is no such page.
      def turn(delta)
        target = @page + delta
        return ''.b unless target.between?(0, pages - 1)

        @page  = target
        @index = 0
        frame
      end

      # Selects +slot+ on this page; the repaint of the old and the new tile's
      # hearts and of the info lines.
      def select(slot)
        return ''.b if slot == @index || slot.negative? || slot >= on_page.size

        canvas = Canvas.new
        old = @index
        @index = slot
        hearts(canvas, old)
        hearts(canvas, slot)
        info(canvas)
        [old, slot].map { |s| heart_spans(canvas, s) }.join + info_spans(canvas) + rest
      end

      # A few stars change place and colour: an idle tick.
      def twinkle
        canvas = Canvas.new
        out = +''.b
        2.times do
          row = STAR_ROWS.sample(random: @random)
          col = star_cols(row).sample(random: @random)
          canvas.text(row, col, STARS.sample(random: @random), STAR_COLORS.sample(random: @random))
          out << canvas.span(row, col, 1)
        end
        out + rest
      end

      # The dialling of the selected board: its button flashes, then the
      # info says where the call goes. Yields each step's bytes, with a pause
      # after it.
      def dial_steps
        board = selected
        slot  = @index
        steps = []
        3.times do
          steps << tile_spans(slot, flash: true) << tile_spans(slot, flash: false)
        end
        canvas = Canvas.new
        line = "DIALLING #{board.address.upcase}"
        canvas.text(INFO_ROW, 1, line.ljust(38), Canvas::WHITE)
        canvas.text(INFO_ROW + 1, 1, ''.ljust(38), Canvas::WHITE)
        steps << (canvas.span(INFO_ROW, 1, 38) + canvas.span(INFO_ROW + 1, 1, 38))
        3.times do |i|
          dots = Canvas.new.text(INFO_ROW + 1, 1 + (i * 2), '●', STRIPE[i * 2])
          steps << dots.span(INFO_ROW + 1, 1 + (i * 2), 1)
        end
        steps
      end

      def self.color(board) = UI::Colors.c64(board.rgb)

      private

      def rest = Canvas.new.cursor(HELP_ROW, 0)

      def centre(text) = (Canvas::COLS - text.length) / 2

      def star_cols(row) = row.zero? ? (0..38).step(3).to_a : [0, 1, 2, 3, 36, 37, 38, 39]

      def stars(canvas)
        STAR_ROWS.each do |row|
          star_cols(row).each do |col|
            next unless @random.rand < 0.45

            canvas.text(row, col, STARS.sample(random: @random), STAR_COLORS.sample(random: @random))
          end
        end
      end

      def logo(canvas)
        rows = 5.times.map { |r| 'TTG GATE'.chars.map { |c| FONT.fetch(c)[r] }.join('.') }
        rows.each_with_index do |line, r|
          line.each_char.with_index do |ch, c|
            next if ch == '.'

            shadow_r = r + 1
            shadow_c = c + 1
            shadow_free = shadow_r >= rows.size || rows[shadow_r][shadow_c].nil? || rows[shadow_r][shadow_c] == '.'
            canvas.text(LOGO_TOP + shadow_r, LOGO_LEFT + shadow_c, '▒', Canvas::DARK_GREY) if shadow_free
            canvas.text(LOGO_TOP + r, LOGO_LEFT + c, FONT_GLYPHS.fetch(ch), RAINBOW[r])
          end
        end
      end

      def stripe(canvas, row)
        Canvas::COLS.times { |c| canvas.text(row, c, '▄', STRIPE[(c / 5) % STRIPE.size]) }
      end

      def origin(slot) = [TILE_TOP + ((slot / 2) * 3), TILE_COLS[slot % 2]]

      # A candy button: a rounded band in the board's colour, its digit on a
      # white key; an empty place is a grey free line.
      def tile(canvas, slot, flash: false)
        row, col = origin(slot)
        board = on_page[slot]
        color = board ? Switchboard.color(board) : Canvas::DARK_GREY
        color = Canvas::WHITE if flash
        inner = TILE_WIDTH - 2
        canvas.text(row, col, "◢#{'▄' * inner}◣", color)
        canvas.text(row + 2, col, "◥#{'▀' * inner}◤", color)
        if board
          canvas.text(row + 1, col, ' ', color, rvs: true)
          canvas.text(row + 1, col + 1, (slot + 1).to_s, flash ? color : Canvas::WHITE, rvs: true)
          name = board.name.upcase[0, NAME_WIDTH].center(NAME_WIDTH)
          canvas.text(row + 1, col + 2, " #{name} ", color, rvs: true)
        else
          canvas.text(row + 1, col, '█', color)
          canvas.text(row + 1, col + 1, ' FREE LINE '.center(inner), Canvas::GREY)
          canvas.text(row + 1, col + TILE_WIDTH - 1, '█', color)
        end
        hearts(canvas, slot)
      end

      def hearts(canvas, slot)
        row, col = origin(slot)
        on = slot == @index && on_page[slot]
        canvas.text(row + 1, col - 1, on ? '♥' : ' ', Canvas::LIGHT_RED)
        canvas.text(row + 1, col + TILE_WIDTH, on ? '♥' : ' ', Canvas::LIGHT_RED)
      end

      def heart_spans(canvas, slot)
        row, col = origin(slot)
        canvas.span(row + 1, col - 1, 1) + canvas.span(row + 1, col + TILE_WIDTH, 1)
      end

      def tile_spans(slot, flash:)
        canvas = Canvas.new
        tile(canvas, slot, flash: flash)
        row, col = origin(slot)
        (0..2).map { |r| canvas.span(row + r, col, TILE_WIDTH) }.join
      end

      def page_dots(canvas)
        return if pages == 1

        dots = pages.times.map { |p| p == @page ? '●' : '○' }.join(' ')
        text = "- #{dots} +"
        canvas.text(PAGES_ROW, centre(text), text, Canvas::YELLOW)
      end

      def info(canvas)
        board = selected
        canvas.clear(INFO_ROW, 1, 38).clear(INFO_ROW + 1, 1, 38)
        return unless board

        color = Switchboard.color(board)
        canvas.text(INFO_ROW, 1, '♦', color)
        canvas.text(INFO_ROW, 3, board.address.upcase[0, 36], Canvas::WHITE)
        canvas.text(INFO_ROW + 1, 3, board.tags.join(' ♦ ').upcase[0, 36], color)
      end

      def info_spans(canvas) = canvas.span(INFO_ROW, 1, 38) + canvas.span(INFO_ROW + 1, 1, 38)
    end
  end
end
