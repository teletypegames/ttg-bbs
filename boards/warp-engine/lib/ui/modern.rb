# frozen_string_literal: true

require_relative 'transfer'
require_relative 'logo'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): a desktop
  # under a menubar, the shelves in a two-pane window, a shelf's titles with
  # the one picked on the right, and its download by ZMODEM, XMODEM-1K or
  # XMODEM.
  module Modern
    def self.flow(bbs)
      app = BBS::Application.define do
        theme BBS::Theme.synchronet
        services bbs.services

        helpers do
          def shelf_list = open_window(:shelves)

          def open_shelf(shelf)
            titles = with_loading("Reading the #{shelf.name} shelf…") { services[:catalog].titles(shelf) }
            if titles
              open_window(:titles, shelf: shelf, titles: titles)
            else
              BBS::Dialogs.message(self, 'The archive did not answer. Try again later.', title: ' Shelf ')
            end
          end

          def reload(window, shelf)
            titles = with_loading("Reading the #{shelf.name} shelf…") { services[:catalog].titles(shelf, fresh: true) }
            if titles
              window.replace_items(titles)
            else
              BBS::Dialogs.message(self, 'The archive did not answer. Try again later.', title: ' Reload ')
            end
          end

          def download(title, protocol)
            catalog = services[:catalog]
            data = with_loading("Fetching #{title.file}…") { catalog.fetch(title) }
            return BBS::Dialogs.message(self, Transfer.refusal(data, title), title: ' Download ', width: 64) if data.is_a?(Symbol)

            result = with_line do |session|
              text = BBS::FrameBuffer.wrap_ansi(Transfer.start(protocol, title), cols - 4)
              session.write("\r\n#{text.map { |l| "  #{l}\r\n" }.join}\r\n")
              Transfer.send_file(session, protocol, title, data)
            end
            catalog.downloaded(title, protocol) if result == :ok
            BBS::Dialogs.message(self, Transfer.result(result, protocol, title), title: ' Download ', width: 64)
          end

          def selected(window) = window.list_widget.selected_item

          def status_text = "#{services[:catalog].shelves.size} shelves │ #{Time.now.strftime('%H:%M')}"

          def desktop_label(text, style, x, y, width, align: :left)
            label = BBS::Widgets::Label.new(text: text, align: align, style_key: style)
            label.layout(x, y, width, 1)
            add(label)
          end
        end

        window :shelves, type: :master_detail do |w|
          w.title         ' Shelves '
          w.height        { |ctx| ctx[:app].rows - 8 }
          w.list_width    { |ctx| [30, ctx[:app].cols / 3].max }
          w.items         { |ctx| ctx[:catalog].shelves }
          w.item_label    { |s, _ctx| s.name }
          w.empty_message 'No shelves are configured.'
          w.render_detail do |s, width, ctx|
            t = ctx[:app].theme
            ["#{t[:text_bright]}#{s.name}#{t[:text]}", '',
             *BBS::FrameBuffer.wrap_ansi(s.about, width - 1), '',
             *BBS::FrameBuffer.wrap_ansi("#{t[:text_dim]}#{ctx[:app].services[:catalog].url(s)}/#{t[:text]}", width - 1)]
          end
          w.bottom_meta { |_s, _ctx| 'Enter opens the shelf' }
          w.on_activate { |s, _window, ctx| ctx[:app].open_shelf(s) }
          w.action(label: '&Open') do |win, ctx|
            shelf = ctx[:app].selected(win)
            ctx[:app].open_shelf(shelf) if shelf
            :keep
          end
        end

        window :titles, type: :master_detail do |w|
          w.maximizable true
          w.title         { |ctx| " #{ctx[:shelf].name} " }
          w.height        { |ctx| ctx[:app].rows - 8 }
          w.list_width    { |ctx| [30, ctx[:app].cols / 3].max }
          w.items         { |ctx| ctx[:titles] }
          w.item_label    { |t, _ctx| t.title }
          w.empty_message 'This shelf is empty right now.'
          w.render_detail do |t, width, ctx|
            th      = ctx[:app].theme
            catalog = ctx[:app].services[:catalog]
            count   = catalog.downloads(t)
            ["#{th[:text_bright]}#{t.title}#{th[:text]}",
             "#{th[:accent]}#{[t.version.empty? ? '' : "v#{t.version}", t.author].reject(&:empty?).join(' · ')}#{th[:text]}",
             "#{th[:text_dim]}#{t.file} · #{t.size} bytes · #{count} download#{'s' unless count == 1}#{th[:text]}", '',
             *BBS::FrameBuffer.wrap_ansi(t.about, width - 1), '',
             *BBS::FrameBuffer.wrap_ansi("#{th[:label]}On a Commodore:#{th[:text]} LOAD\"#{t.disk_name}\",8,1, RUN", width - 1),
             *BBS::FrameBuffer.wrap_ansi("#{th[:label]}Over HTTP:#{th[:text]} #{catalog.url(t)}", width - 1)]
          end
          w.bottom_meta { |t, _ctx| "CRC-32 #{format('%08x', t.crc32)}" }
          w.on_activate { |t, _window, ctx| ctx[:app].download(t, :zmodem) }
          w.action(label: '&ZMODEM') do |win, ctx|
            title = ctx[:app].selected(win)
            ctx[:app].download(title, :zmodem) if title
            :keep
          end
          w.action(label: 'XMODEM-1&K') do |win, ctx|
            title = ctx[:app].selected(win)
            ctx[:app].download(title, :xmodem_1k) if title
            :keep
          end
          w.action(label: 'X&MODEM') do |win, ctx|
            title = ctx[:app].selected(win)
            ctx[:app].download(title, :xmodem) if title
            :keep
          end
          w.action(label: '&Reload') do |win, ctx|
            ctx[:app].reload(win, ctx[:shelf])
            :keep
          end
        end

        menubar do
          menu '&Files' do
            item '&Shelves', shortcut: 'F2' do shelf_list end
            separator
            item '&Log off', shortcut: 'Alt-X' do :halt end
          end
          menu '&Help' do
            item '&About' do
              BBS::Dialogs.message(self,
                'WarpEngine BBS — the file area of Teletype Games on a telnet line, powered by rubbs. ' \
                'The shelves are the folders the WarpEngine of teletypegames.org keeps for machines without ' \
                'a web browser: pick one, pick a title, and take it home by ZMODEM or XMODEM.',
                title: ' About ', width: 64)
            end
            item '&Downloads' do
              BBS::Dialogs.message(self,
                'ZMODEM (Enter or Z): SyncTERM, NetRunner, Qodem and the web terminal start it by themselves. ' \
                'XMODEM-1K (K) and XMODEM (M): start the download in your terminal, name the file, and the board ' \
                'sends it; a Commodore terminal (CCGMS, Novaterm, UltimateTerm) takes these. Every file is checked ' \
                'against its shelf before it goes.',
                title: ' Downloads ', width: 64)
            end
            item '&Keys' do
              BBS::Dialogs.message(self,
                'F2 Shelves · Enter — open / ZMODEM · Alt+letter — the buttons and the menus · ' \
                'Tab/Shift-Tab — move focus · Esc — close window · F5 or Alt-Enter — full screen and back · ' \
                'F6 / Shift-F6 — next / previous window · F10 Menu · Alt-X Log off',
                title: ' Keys ', width: 64)
            end
          end
        end

        status_hint('F2',  'Shelves') { shelf_list }
        status_hint('F10', 'Menu') { menubar.open(0) }
        status_hint('Alt-X', 'Bye') { :halt }

        on_tick { statusbar.right_text = status_text }

        init do
          mark = ((cols - Logo.half_blocks.first.length) / 2) + 1
          Logo.half_blocks.each_with_index { |row, i| desktop_label(row, :accent, mark, 2 + i, row.length) }
          desktop_label('─── the file area of Teletype Games ───', :text_dim, 1, rows - 2, cols, align: :center)
          statusbar.right_text = status_text
          shelf_list
        end
      end

      BBS::Flow.define do
        call do |ctx, runner|
          app.run(session: runner.session, session_id: ctx[:session_id], context: ctx)
          nil
        end
        call do |_ctx, runner|
          runner.write "\e[0m\e[2J\e[H\r\n  \e[1;37mThanks for calling WarpEngine BBS.\e[0m\r\n  " \
                       "\e[2;37mMore of us: teletypegames.org\e[0m\r\n\r\n  \e[1;31mNO CARRIER\e[0m\r\n\r\n"
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end
  end
end
