# frozen_string_literal: true

require_relative '../glyph_keys'
require_relative 'canvas_panel'

module UI
  module Modern
    # The shared canvas in a window: the 40×25 picture on the left (scrolled
    # when the window is lower than 25 rows), a side panel on the right with
    # the ink, the sixteen colours and the glyphs to click, the cursor's
    # place, who else is painting and the keys.
    #
    # Keys: the arrows move; a typed character paints itself (in glyph mode
    # the letters paint graphics, see GlyphKeys); Enter paints the brush and
    # moves on; Backspace and Delete rub out; F7 and F8 step the ink, F9 or
    # Ctrl-R reverse, Insert or Ctrl-G glyph mode; Ctrl-S saves to the Wall,
    # Ctrl-Z or Ctrl-U undoes. Mouse: a click puts the cursor, dragging or a
    # right click paints the brush, a click in the panel picks an ink or a
    # brush.
    class CanvasWidget < BBS::Widget
      include CanvasPanel

      ROWS  = CanvasModel::ROWS
      PANEL = 24
      WIDTH = COLS + 1 + PANEL
      MOVES = %i[up down left right home end page_up page_down].freeze

      attr_reader :ink, :reverse, :brush

      # +canvas+ the CanvasService, +who+ the session id; +on_save+ is called
      # (with no arguments) for Ctrl-S and the panel's Save.
      def initialize(canvas:, who:, on_save:, **kw)
        super(**kw)
        @canvas  = canvas
        @who     = who
        @on_save = on_save
        @x       = 0
        @y       = 0
        @top     = 0
        @ink     = 1
        @reverse = false
        @glyphs  = false
        @brush   = '█'
        @message = nil
        @hits    = []
      end

      def focusable? = true

      def view_rows = [bounds.height, ROWS].min

      def flash(text) = (@message = text)

      def render(frame)
        @canvas.touch(@who)
        snapshot = @canvas.snapshot
        follow
        @hits = []
        frame.fill(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height, sgr: style(:text))
        draw_canvas(frame, snapshot)
        frame.vline(x: bounds.x + COLS, y: bounds.y, length: bounds.height, sgr: style(:window_border))
        draw_panel(frame)
      end

      def handle_event(event)
        return mouse(event.mouse) if event.mouse?
        return nil unless event.key?

        @message = nil
        key(event.key)
      end

      private

      # ── keys and mouse ────────────────────────────────────────────────

      # Does what the key +k+ asks: :handled, or nil when it is not one of
      # the canvas.
      def key(k)
        if MOVES.include?(k) then move(k)
        elsif k.is_a?(String) then paint(@glyphs ? GlyphKeys.glyph(k) : k)
        else return command(k)
        end
        :handled
      end

      def command(k)
        case k
        when :backspace then rub_out(-1)
        when :delete then rub_out(0)
        when :enter then paint(@brush)
        when :f7, :f8 then @ink = (@ink + (k == :f8 ? 1 : -1)) % ColorModel.count
        when :f9, :ctrl_r then @reverse = !@reverse
        when :insert, :ctrl_g then @glyphs = !@glyphs
        when :ctrl_s then @on_save.call
        when :ctrl_z, :ctrl_u then undo
        else return nil
        end
        :handled
      end

      def undo = flash(@canvas.undo(@who) == :ok ? 'Undone.' : 'Nothing to undo.')

      def move(key)
        case key
        when :up        then @y -= 1
        when :down      then @y += 1
        when :left      then @x -= 1
        when :right     then @x += 1
        when :home      then @x = 0
        when :end       then @x = COLS - 1
        when :page_up   then @y = 0
        when :page_down then @y = ROWS - 1
        end
        @x = @x.clamp(0, COLS - 1)
        @y = @y.clamp(0, ROWS - 1)
      end

      def paint(char, advance: true)
        case @canvas.paint(@who, @x, @y, char, @ink, reverse: @reverse)
        when :ok then @x = [@x + 1, COLS - 1].min if advance
        when :too_fast then flash('Slow down: 20 cells a second.')
        when :bad_glyph then flash('The canvas has no such glyph.')
        end
      end

      def rub_out(step)
        @x = [@x + step, 0].max
        flash('Slow down: 20 cells a second.') if @canvas.erase(@who, @x, @y) == :too_fast
      end

      def mouse(m)
        if m.kind == :wheel then @top = (@top + (m.button == :up ? -3 : 3)).clamp(0, ROWS - view_rows)
        elsif (cell = canvas_cell(m.x, m.y)) then point(m, cell)
        elsif m.kind == :press && m.button == :left then click_panel(m)
        end
        :handled
      end

      # The pointer on the canvas: the cursor goes there, and a drag with the
      # left button or a right click paints the brush.
      def point(m, cell)
        @x, @y = cell
        paint(@brush, advance: false) if (m.kind == :move && m.button == :left) || (m.kind == :press && m.button == :right)
      end

      def click_panel(m)
        hit = @hits.find { |x, y, w, _| m.y == y && m.x >= x && m.x < x + w }
        hit&.last&.call
      end

      def canvas_cell(mx, my)
        x = mx - bounds.x
        y = my - bounds.y + @top
        x.between?(0, COLS - 1) && (my - bounds.y).between?(0, view_rows - 1) ? [x, y] : nil
      end

      def follow
        @top = @y if @y < @top
        @top = @y - view_rows + 1 if @y >= @top + view_rows
        @top = @top.clamp(0, ROWS - view_rows)
      end
    end

    # The window of the canvas: as large as the desktop lets it be, at most
    # the whole canvas and its panel.
    class CanvasWindow < BBS::Window
      attr_reader :widget

      def initialize(app, canvas:, who:, on_save:)
        super(title: 'The Canvas', on_close: ->(_w) { canvas.leave(who) })
        @widget = CanvasWidget.new(canvas: canvas, who: who, on_save: on_save)
        add(@widget)
        place(*rect(app))
        reset_focus
        focus_manager.focus(@widget)
      end

      def resizable? = true

      def normal_rect = rect(@app)

      def place(x, y, width, height)
        layout(x, y, width, height)
        @widget.layout(x + 1, y + 1, width - 2, height - 2)
      end

      private

      def rect(app)
        dx, dy, dw, dh = app.desktop_rect
        w = [CanvasWidget::WIDTH + 2, dw].min
        h = [CanvasModel::ROWS + 2, dh].min
        [dx + ((dw - w) / 2), dy + ((dh - h) / 2), w, h]
      end
    end
  end
end
