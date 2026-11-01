# frozen_string_literal: true

module UI
  module Modern
    # A shelf's window: its titles, the one picked on the right, and the
    # buttons of the three protocols.
    module Titles
      PROTOCOL_BUTTONS = { '&ZMODEM' => :zmodem, 'XMODEM-1&K' => :xmodem_1k, 'X&MODEM' => :xmodem }.freeze

      def self.define(app)
        app.window(:titles, type: :master_detail) do |w|
          layout(w)
          behaviour(w)
        end
      end

      def self.layout(w)
        w.maximizable true
        w.title         { |ctx| " #{ctx[:shelf].name} " }
        w.height        { |ctx| ctx[:app].rows - 8 }
        w.list_width    { |ctx| [30, ctx[:app].cols / 3].max }
        w.items         { |ctx| ctx[:titles] }
        w.item_label    { |t, _ctx| t.title }
        w.empty_message 'This shelf is empty right now.'
        w.render_detail { |t, width, ctx| detail(t, width, ctx[:app]) }
      end

      def self.behaviour(w)
        w.bottom_meta { |t, _ctx| "CRC-32 #{format('%08x', t.crc32)}" }
        w.on_activate { |t, _window, ctx| ctx[:app].download(t, :zmodem) }
        PROTOCOL_BUTTONS.each do |label, protocol|
          w.action(label: label) { |win, ctx| ctx[:app].with_selected(win) { |t| ctx[:app].download(t, protocol) } }
        end
        w.action(label: '&Reload') do |win, ctx|
          ctx[:app].reload(win, ctx[:shelf])
          :keep
        end
      end

      def self.detail(title, width, app)
        th = app.theme
        [*head(title, th, app.catalog.downloads(title)), '',
         *BBS::FrameBuffer.wrap_ansi(title.about, width - 1), '',
         *BBS::FrameBuffer.wrap_ansi("#{th[:label]}On a Commodore:#{th[:text]} LOAD\"#{title.disk_name}\",8,1, RUN",
                                     width - 1),
         *BBS::FrameBuffer.wrap_ansi("#{th[:label]}Over HTTP:#{th[:text]} #{app.catalog.url(title)}", width - 1)]
      end

      # The name, the version and author, the file and its downloads.
      def self.head(title, th, count)
        byline = [title.version.empty? ? '' : "v#{title.version}", title.author].reject(&:empty?).join(' · ')
        ["#{th[:text_bright]}#{title.title}#{th[:text]}",
         "#{th[:accent]}#{byline}#{th[:text]}",
         "#{th[:text_dim]}#{title.file} · #{title.size} bytes · #{count} download#{'s' unless count == 1}#{th[:text]}"]
      end
    end
  end
end
