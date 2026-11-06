# frozen_string_literal: true

module UI
  module Modern
    # The drawing of a CanvasWidget: the picture, and the side panel with
    # the ink, the swatches and glyphs to click (kept in @hits), the place
    # of the cursor, the buttons and the keys.
    module CanvasPanel
      COLS = CanvasModel::COLS
      GLYPHS_PER_ROW = 12

      private

      def draw_canvas(frame, snapshot)
        view_rows.times do |row|
          y = @top + row
          COLS.times do |x|
            char, fg, bg = snapshot.at(x, y)
            sgr = ArtLines.canvas_sgr(fg, bg)
            sgr = "#{sgr}\e[7m" if x == @x && y == @y
            frame.move(bounds.x + x, bounds.y + row)
            frame.write(char, sgr: sgr)
          end
        end
      end

      def draw_panel(frame)
        @row = 0
        @px  = bounds.x + COLS + 1
        @pw  = bounds.width - COLS - 1
        brush_lines(frame)
        heading(frame, 'inks F7 F8')
        2.times { |r| swatches(frame, r * 8) }
        heading(frame, 'brush (Enter)')
        GlyphModel::PALETTE.each_slice(GLYPHS_PER_ROW) { |slice| glyph_row(frame, slice) }
        heading(frame, 'painting')
        text_line(frame, [[format('x %<x>02d  y %<y>02d  ', x: @x, y: @y), :text], ["#{@canvas.painters} here", :accent]])
        text_line(frame, [[@message.to_s, :accent]])
        buttons(frame)
        help(frame)
      end

      def brush_lines(frame)
        text_line(frame, [['Ink ', :text], ['██', ArtLines.canvas_sgr(@ink, 0)], [" #{ColorModel[@ink].name}", :text_bright]])
        text_line(frame, [['Rvs ', :text], [@reverse ? 'on ' : 'off', :text_bright], [' F9  ', :text_dim],
                          [@glyphs ? 'Glyphs' : 'Text', :text_bright]])
      end

      def put(frame, x, text, sgr)
        frame.move(x, bounds.y + @row)
        frame.write(text, sgr: sgr)
      end

      def resolve(sgr) = sgr.is_a?(Symbol) ? style(sgr) : sgr

      def room? = @row < bounds.height

      def text_line(frame, runs)
        return unless room?

        x = @px
        runs.each do |text, sgr|
          text = text[0, [@pw - (x - @px), 0].max]
          put(frame, x, text, resolve(sgr))
          x += text.length
        end
        @row += 1
      end

      def heading(frame, text)
        return unless room?

        put(frame, @px, "─ #{text} ".ljust(@pw, '─')[0, @pw], style(:text_dim))
        @row += 1
      end

      def swatches(frame, from)
        return unless room?

        8.times do |i|
          index = from + i
          x     = @px + (i * 3)
          label = index == @ink ? '▐▌' : '  '
          put(frame, x, label, "\e[0;38;5;#{index == 1 ? 16 : 231};48;5;#{ColorModel[index].xterm}m")
          @hits << [x, bounds.y + @row, 2, -> { @ink = index }]
        end
        @row += 1
      end

      def glyph_row(frame, glyphs)
        return unless room?

        glyphs.each_with_index do |g, i|
          x = @px + (i * 2)
          put(frame, x, g, g == @brush ? "#{ArtLines.canvas_sgr(@ink, 0)}\e[7m" : ArtLines.canvas_sgr(@ink, 0))
          @hits << [x, bounds.y + @row, 1, -> { @brush = g }]
        end
        @row += 1
      end

      def buttons(frame)
        return unless room?

        x = @px
        [['[Save]', @on_save], ['[Undo]', -> { undo }],
         ['[Rvs]', -> { @reverse = !@reverse }], ['[Gly]', -> { @glyphs = !@glyphs }]].each do |label, action|
          put(frame, x, label, style(:accent))
          @hits << [x, bounds.y + @row, label.length, action]
          x += label.length
        end
        @row += 1
      end

      def help(frame)
        lines = if @glyphs
                  GlyphKeys.legend(6)
                else
                  ['^S save  ^Z undo  Esc', 'Ins glyphs  ^R reverse', 'Type to paint']
                end
        lines.each { |l| text_line(frame, [[l, :text_dim]]) }
      end
    end
  end
end
