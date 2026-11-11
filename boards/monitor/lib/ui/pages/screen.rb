# frozen_string_literal: true

module UI
  # A page of the board on either face (Rubbs::Common::Screens::Page): a
  # header (MONITOR, where the caller is, a word at the right), the body,
  # and a hint line at the bottom, where a line being read is shown too.
  # A page gives #crumb, #right, #body (lines of runs, UI::Paint, for its
  # width and rows) and #hint.
  class Screen < Rubbs::Common::Screens::Page
    # The columns of air at the left on a modern terminal.
    MARGIN = 1

    # The face drawn for: +:modern+ or +:petscii+.
    def face = pages.petscii? ? :petscii : :modern

    # Whether it draws for a C64.
    def petscii? = pages.petscii?

    # The columns a line takes.
    def width = petscii? ? Rubbs::Petscii::Canvas::COLS : session.term_cols.to_i.clamp(40, 250) - (2 * MARGIN)

    # The rows of the screen (the last one of a modern terminal left free).
    def height = petscii? ? Rubbs::Petscii::Canvas::ROWS : session.term_rows.to_i.clamp(12, 120) - 1

    # The rows the body has.
    def body_rows = height - 2

    # Draws the page.
    def draw(screen)
      rows  = Array(body).first(body_rows)
      blank = Array.new(body_rows - rows.size) { [] }
      lines = [header] + rows + blank + [footer]
      petscii? ? draw_canvas(screen, lines) : draw_frame(screen, lines)
      prompt_cursor(lines.size - 1) if pages.line && !petscii?
    end

    # Where the caller is, after MONITOR.
    def crumb = ''

    # The words at the right of the header.
    def right = ''

    # The lines of the body.
    def body = []

    # The keys of the page, for the hint line.
    def hint = ''

    private

    def draw_frame(frame, lines)
      print_lines(frame, lines.map { |l| Modern.ansi(Paint.fit(l, width)) }, x: MARGIN + 1, y: 1)
    end

    def draw_canvas(canvas, lines)
      lines.each_with_index { |l, row| Petscii.canvas(canvas, row, Paint.fit(l, width)) }
    end

    def header
      title = petscii? ? 'MONITOR' : 'MONITOR BBS'
      left  = [[" #{title} ", :bright, :lit], [" #{Paint.plain(crumb)}", :accent]]
      tail  = Paint.plain(right)
      gap   = [width - Paint.width(left) - tail.length, 1].max
      [*left, [' ' * gap, :dim], [tail, :dim]]
    end

    def footer
      return prompt_line if pages.line

      Paint.run(hint, :dim)
    end

    def prompt_line
      label = "#{pages.line.label} "
      [[label, :accent], [pages.line.tail(width - label.length - 2), :bright], [' ', :bright, (:lit if petscii?)].compact]
    end

    def prompt_cursor(row)
      label = "#{pages.line.label} "
      col = label.length + pages.line.tail(width - label.length - 2).length
      cursor(row + 1, MARGIN + col + 1)
    end

    # The panel's +visual+ in a box: Render's lines.
    def render(visual, rows, range, **)
      from, to = range.millis
      Render.new(visual, width: width, height: rows, face: face, from: from, to: to, **).lines
    end
  end
end
