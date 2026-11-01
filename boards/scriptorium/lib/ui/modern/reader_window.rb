# frozen_string_literal: true

module UI
  module Modern
    # The text of a chapter in a scrolling pane, wrapped to the pane's
    # width; the arrow keys left and right turn to the previous and the
    # next chapter, as do the Prev and Next buttons.
    class ChapterView < BBS::Widgets::ScrollView
      attr_accessor :on_turn

      def handle_event(event)
        if event.key? && %i[left right].include?(event.key) && @on_turn
          @on_turn.call(event.key == :left ? -1 : 1)
          return :handled
        end
        super
      end
    end

    # A window that reads a book chapter by chapter: the chapter wrapped to
    # the window (wrapped again when it is resized or maximized), PgUp/PgDn,
    # Home/End and the arrows to move, ←/→ (or P/N) for the previous and the
    # next chapter, and a line under the text that says where the reader is:
    # "Chapter 3/42 · page 2/9". Only the chapter shown is in memory; the
    # next one is read from the cache when the reader turns to it.
    class ReaderWindow < BBS::Window
      MAX_WIDTH = 100

      def self.open(app, **kw) = new(app: app, **kw).tap(&:attach)

      def initialize(app:, reading:, book:, text:, number: 1)
        super(title: " #{book.short_title[0, 50]} ", modal: false, maximizable: true)
        self.theme = app.theme
        @app     = app
        @reading = reading
        @book    = book
        @text    = text
        @view    = ChapterView.new
        @view.on_turn = ->(step) { turn(step) }
        @where = BBS::Widgets::Label.new(text: '', style_key: :input_label)
        add(@view)
        add(@where)
        @buttons = [{ label: '&Prev', keep_open: true, align: :left, on_click: ->(_w) { turn(-1) } },
                    { label: '&Next', keep_open: true, align: :left, on_click: ->(_w) { turn(1) } },
                    { label: '&Close', cancel: true }]
        layout(*normal_rect)
        @bar = BBS::Windows::ButtonBar.attach(self, app, @buttons)
        load(number)
        place(*normal_rect)
      end

      def attach
        @app.open_window(self)
        reset_focus
        focus_manager.focus(@view)
        self
      end

      def resizable? = true

      # A page of a book: as wide as the screen allows up to MAX_WIDTH, as
      # tall as the desktop less a row above and below.
      def normal_rect
        _, dy, dw, dh = @app.desktop_rect
        w = [dw - 4, MAX_WIDTH].min
        h = [dh - 2, BBS::Window::MIN_HEIGHT].max
        [((dw - w) / 2) + 1, dy + 1, w, h]
      end

      def place(x, y, width, height)
        layout(x, y, width, height)
        @view.layout(x + 2, y + 1, [width - 3, 1].max, [height - 4, 1].max)
        @where.layout(x + 2, y + height - 3, [width - 4, 1].max, 1)
        BBS::Windows::ButtonBar.place(self, @bar[:widgets], @buttons)
        rewrap
      end

      def render(frame)
        @where.text = where
        super
      end

      private

      def load(number)
        @chapter_no = number
        @paragraphs = (@reading.chapter(@text, number) || '(This chapter could not be read. Try again later.)').split("\n\n")
        @view.scroll = 0
        rewrap(keep: false)
      end

      def turn(step)
        number = @chapter_no + step
        load(number) if number.between?(1, @text.size)
        :handled
      end

      # The chapter wrapped to the pane, the heading bright; with +keep+ the
      # reader stays at the same place in the text.
      def rewrap(keep: true)
        width = [@view.bounds.width - 1, 10].max
        ratio = keep && !@view.lines.empty? ? @view.scroll.to_f / @view.lines.size : 0
        th    = @app.theme
        lines = []
        @paragraphs.each_with_index do |para, i|
          lines << '' unless i.zero?
          para.split("\n").each do |line|
            wrapped = BBS::FrameBuffer.wrap_ansi(line, width)
            wrapped = wrapped.map { |l| "#{th[:text_bright]}#{l}#{th[:text]}" } if i.zero?
            lines.concat(wrapped)
          end
        end
        @view.lines  = lines
        @view.scroll = (ratio * lines.size).floor.clamp(0, [lines.size - @view.bounds.height, 0].max)
      end

      def where
        h     = [@view.bounds.height, 1].max
        pages = [(@view.lines.size + h - 1) / h, 1].max
        page  = [((@view.scroll + h - 1) / h) + 1, pages].min
        title = @text.chapter(@chapter_no)&.title.to_s
        "Chapter #{@chapter_no}/#{@text.size} · page #{page}/#{pages} · #{title}"
      end
    end
  end
end
