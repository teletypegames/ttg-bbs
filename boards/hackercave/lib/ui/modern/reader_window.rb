# frozen_string_literal: true

module UI
  module Modern
    # A window that reads an RFC as the RFC Editor published it: its lines
    # unchanged, in a pane at least 72 columns wide when the screen allows
    # (the running heads and feet of the pages dim, the headings bright),
    # PgUp/PgDn, Home/End and the arrows to move, and a line under the text
    # that says where the reader is: "RFC 793 · page 3/91 · line 140/5247".
    class ReaderWindow < BBS::Window
      # 73 columns of text (a few RFCs have 73), the border and a margin.
      MAX_WIDTH = 78

      def self.open(app, **kw) = new(app: app, **kw).tap(&:attach)

      def initialize(app:, reading:, rfc:, doc:)
        super(title: " #{rfc.name}: #{rfc.title[0, 50]} ", modal: false, maximizable: true)
        self.theme = app.theme
        @app   = app
        @rfc   = rfc
        @doc   = doc
        @view  = BBS::Widgets::ScrollView.new
        @where = BBS::Widgets::Label.new(text: '', style_key: :input_label)
        add(@view)
        add(@where)
        @buttons = [{ label: '&Links', keep_open: true, align: :left, on_click: ->(_w) { @app.links(@rfc) } },
                    { label: '&QR code', keep_open: true, align: :left, on_click: ->(_w) { @app.show_qr(@rfc) } },
                    { label: '&Close', cancel: true }]
        layout(*normal_rect)
        @bar = BBS::Windows::ButtonBar.attach(self, app, @buttons)
        @view.lines = styled(reading.kinds(doc))
        place(*normal_rect)
      end

      def attach
        @app.open_window(self)
        reset_focus
        focus_manager.focus(@view)
        self
      end

      def resizable? = true

      # As wide as the screen allows up to MAX_WIDTH, as tall as the desktop
      # less a row above and below.
      def normal_rect
        _, dy, dw, dh = @app.desktop_rect
        w = [dw - 2, MAX_WIDTH].min
        h = [dh - 2, BBS::Window::MIN_HEIGHT].max
        [((dw - w) / 2) + 1, dy + 1, w, h]
      end

      def place(x, y, width, height)
        layout(x, y, width, height)
        @view.layout(x + 2, y + 1, [width - 3, 1].max, [height - 4, 1].max)
        @where.layout(x + 2, y + height - 3, [width - 4, 1].max, 1)
        BBS::Windows::ButtonBar.place(self, @bar[:widgets], @buttons)
        keep_in_view
      end

      def render(frame)
        @where.text = where
        super
      end

      private

      # The scroll within the text after a resize.
      def keep_in_view = @view.scroll = @view.scroll.clamp(0, [@view.lines.size - @view.bounds.height, 0].max)

      # The lines of the RFC, a page's head and foot dim, a heading bright.
      def styled(kinds)
        th = @app.theme
        @doc.lines.each_with_index.map do |line, i|
          case kinds[i]
          when :page then "#{th[:text_dim]}#{line}#{th[:text]}"
          when :heading then "#{th[:text_bright]}#{line}#{th[:text]}"
          else line
          end
        end
      end

      def where
        top = @view.scroll
        last = [top + @view.bounds.height, @doc.size].min
        page = @doc.paged? ? "page #{@doc.page_of(top)}/#{@doc.pages} · " : ''
        "#{@rfc.name} · #{page}line #{last}/#{@doc.size} · #{100 * last / [@doc.size, 1].max}%"
      end
    end
  end
end
