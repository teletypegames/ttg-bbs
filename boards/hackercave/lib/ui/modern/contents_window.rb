# frozen_string_literal: true

module UI
  module Modern
    # The table of contents of the RFC a ReaderWindow shows: its headings on
    # the left; Enter takes the reader there.
    module ContentsWindow
      def self.define(app)
        app.window(:contents, type: :master_detail) do |w|
          frame(w)
          list(w)
        end
      end

      def self.frame(w)
        w.maximizable true
        w.title         { |ctx| " Contents of #{ctx[:rfc].name} (#{ctx[:headings].size}) " }
        w.height        { |ctx| ctx[:app].rows - 8 }
        w.list_width    { |ctx| [52, ctx[:app].cols - 24].min }
      end

      def self.list(w)
        w.items         { |ctx| ctx[:headings] }
        w.item_label    { |(_, text), _ctx| text }
        w.empty_message 'No headings found in this RFC.'
        w.render_detail { |(line, _), _width, _ctx| ["line #{line + 1}", '', 'Enter takes the', 'reader there.'] }
        w.on_activate do |(line, _), window, ctx|
          ctx[:app].close_window(window)
          ctx[:reader].jump(line)
        end
      end
    end
  end
end
