# frozen_string_literal: true

module UI
  module Modern
    # A window of paragraphs ([kind, text]: :heading, :text, :pre) in a
    # scrolling pane, wrapped to its width again when it is resized: an
    # erratum list, a Jargon File entry or one of its chapters. A {word} of a
    # Jargon entry is coloured as a link. +buttons+ go before Close.
    class TextWindow < BBS::Window
      MAX_WIDTH = 84
      LINK = /\{([^{}]+)\}/

      def self.open(app, **kw) = new(app: app, **kw).tap(&:attach)

      def initialize(app:, title:, paragraphs:, buttons: [], where: nil)
        super(title: " #{title[0, 60]} ", modal: false, maximizable: true)
        self.theme = app.theme
        @app        = app
        @paragraphs = paragraphs
        @view       = BBS::Widgets::ScrollView.new
        @where      = BBS::Widgets::Label.new(text: where.to_s, style_key: :input_label)
        add(@view)
        add(@where)
        @buttons = [*buttons, { label: '&Close', cancel: true }]
        layout(*normal_rect)
        @bar = BBS::Windows::ButtonBar.attach(self, app, @buttons)
        place(*normal_rect)
      end

      def attach
        @app.open_window(self)
        reset_focus
        focus_manager.focus(@view)
        self
      end

      def resizable? = true

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

      private

      # The paragraphs wrapped to the pane again, the scroll kept within.
      def rewrap
        @view.lines = lines([@view.bounds.width - 1, 10].max)
        @view.scroll = @view.scroll.clamp(0, [@view.lines.size - @view.bounds.height, 0].max)
      end

      def lines(width)
        @paragraphs.each_with_index.flat_map do |(kind, text), i|
          [*('' unless i.zero?), *paragraph(kind, text, width)]
        end
      end

      def paragraph(kind, text, width)
        th = @app.theme
        case kind
        when :heading then BBS::FrameBuffer.wrap_ansi("#{th[:text_bright]}#{text}#{th[:text]}", width)
        when :pre then text.split("\n").map { |l| "#{th[:text_dim]}#{l[0, width]}#{th[:text]}" }
        else BBS::FrameBuffer.wrap_ansi(text.gsub(LINK) { "#{th[:accent]}#{::Regexp.last_match(1)}#{th[:text]}" }, width)
        end
      end
    end
  end
end
