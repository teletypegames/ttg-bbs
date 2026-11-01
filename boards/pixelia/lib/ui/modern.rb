# frozen_string_literal: true

require_relative 'wall_text'
require_relative 'modern/art_lines'
require_relative 'modern/viewer'
require_relative 'modern/canvas_widget'
require_relative 'modern/logo_widget'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): a desktop
  # under a menubar; the 16colo.rs gallery as years, packs and files in
  # two-pane windows and a piece on the whole screen; the shared canvas in a
  # window of its own; the Wall with a preview of every work.
  module Modern
    def self.flow(bbs)
      app = BBS::Application.define do
        theme BBS::Theme.synchronet
        services bbs.services

        helpers do
          def gallery = services[:gallery]

          def canvas = services[:canvas]

          def wall = services[:wall]

          def unavailable(title) = BBS::Dialogs.message(self, '16colo.rs did not answer. Try again later.', title: title)

          def open_years
            years = with_loading('Reading 16colo.rs…') { gallery.years }
            years ? open_window(:years, years: years) : unavailable(' 16colo.rs ')
          end

          def open_year(year)
            packs = with_loading("Reading the packs of #{year.year}…") { gallery.packs(year) }
            packs ? open_window(:packs, year: year, packs: packs) : unavailable(" #{year.year} ")
          end

          def open_pack(pack)
            files = with_loading("Reading #{pack.name}…") { gallery.files(pack) }
            files ? open_window(:files, pack: pack, files: files) : unavailable(" #{pack.name} ")
          end

          def view_piece(file)
            art = with_loading("Fetching #{file.name}…") { gallery.piece(file) }
            case art
            when :too_big then BBS::Dialogs.message(self, 'This piece is too large for the board.', title: ' Piece ')
            when :unavailable then unavailable(' Piece ')
            else
              title = [file.name, file.credits].reject(&:empty?).join(' · ')
              with_line do |session|
                Viewer.run(session, width: art.width, height: art.height, title: title) { |y, x, w| ArtLines.art(art, y, x, w) }
              end
            end
          end

          def open_canvas
            window = switchable_windows.find { |w| w.is_a?(CanvasWindow) }
            return raise_window(window) if window

            open_window(CanvasWindow.new(self, canvas: canvas, who: session_id, on_save: -> { save_to_wall }))
          end

          def save_to_wall
            wait = wall.wait(session_id)
            return BBS::Dialogs.message(self, WallText.wait(wait), title: ' The Wall ') if wait.positive?
            return BBS::Dialogs.message(self, WallText.result(:blank_canvas), title: ' The Wall ') if canvas.snapshot.empty?

            BBS::Windows::Form.open(self, title: ' Save to the Wall ', width: 52,
              hint: 'The canvas as it is now goes on the Wall. Alt-S saves.',
              fields: [{ key: :title, label: 'Title', max_length: WallService::MAX_TITLE },
                       { key: :handle, label: 'Handle', value: @handle.to_s, max_length: WallService::MAX_HANDLE }],
              submit_label: '&Save',
              on_submit: lambda { |values, form|
                result = wall.save(session_id, title: values[:title], handle: values[:handle])
                unless result.is_a?(WorkModel)
                  form.error(WallText.result(result))
                  next :keep
                end

                @handle = result.handle
                BBS::Dialogs.message(self, WallText.result(result), title: ' The Wall ')
                :close
              })
          end

          def open_wall = open_window(:wall, works: wall.all)

          def view_work(work)
            picture = work.canvas
            with_line do |session|
              Viewer.run(session, width: CanvasModel::COLS, height: CanvasModel::ROWS,
                                  title: "#{work.title} · #{work.handle} · #{work.date}") do |y, x, w|
                ArtLines.canvas(picture, y, x, w)
              end
            end
          end

          def selected(window) = window.list_widget.selected_item

          def status_text = "#{canvas.painters} painting │ #{Time.now.strftime('%H:%M')}"

          def desktop_label(text, style, x, y, width, align: :left)
            label = BBS::Widgets::Label.new(text: text, align: align, style_key: style)
            label.layout(x, y, width, 1)
            add(label)
          end
        end

        window :years, type: :master_detail do |w|
          w.title         ' 16colo.rs '
          w.height        { |ctx| ctx[:app].rows - 6 }
          w.list_width    24
          w.items         { |ctx| ctx[:years] }
          w.item_label    { |y, _ctx| "#{y.year}  #{y.packs.to_s.rjust(4)} packs" }
          w.render_detail do |y, width, ctx|
            t = ctx[:app].theme
            ["#{t[:text_bright]}#{y.year}#{t[:text]}", "#{t[:accent]}#{y.packs} art packs#{t[:text]}", '',
             *BBS::FrameBuffer.wrap_ansi('16colo.rs keeps the art packs of the ANSI and ASCII scene, year by year, ' \
                                         'as the groups released them. Pixelia reads them from its public API and ' \
                                         'draws each piece here, in its 16 colours.', width - 1), '',
             "#{t[:text_dim]}#{ctx[:app].gallery.site_url}/year/#{y.year}#{t[:text]}"]
          end
          w.bottom_meta { |_y, _ctx| 'Enter opens the year' }
          w.on_activate { |y, _window, ctx| ctx[:app].open_year(y) }
        end

        window :packs, type: :master_detail do |w|
          w.maximizable true
          w.title         { |ctx| " 16colo.rs #{ctx[:year].year} " }
          w.height        { |ctx| ctx[:app].rows - 6 }
          w.list_width    { |ctx| [28, ctx[:app].cols / 3].max }
          w.items         { |ctx| ctx[:packs] }
          w.item_label    { |p, _ctx| p.name }
          w.render_detail do |p, width, ctx|
            t = ctx[:app].theme
            ["#{t[:text_bright]}#{p.name}#{t[:text]}", "#{t[:accent]}#{p.credits}#{t[:text]}",
             "#{t[:label]}#{p.year}#{t[:text]}", '',
             *BBS::FrameBuffer.wrap_ansi("#{t[:text_dim]}#{ctx[:app].gallery.pack_url(p)}#{t[:text]}", width - 1)]
          end
          w.bottom_meta { |_p, _ctx| 'Enter opens the pack' }
          w.on_activate { |p, _window, ctx| ctx[:app].open_pack(p) }
        end

        window :files, type: :master_detail do |w|
          w.maximizable true
          w.title         { |ctx| " #{ctx[:pack].name} " }
          w.height        { |ctx| ctx[:app].rows - 6 }
          w.list_width    { |ctx| [24, ctx[:app].cols / 3].max }
          w.items         { |ctx| ctx[:files] }
          w.item_label    { |f, _ctx| f.name }
          w.empty_message 'No text art in this pack.'
          w.render_detail do |f, width, ctx|
            t = ctx[:app].theme
            facts = [['Title', f.title], ['Author', f.author], ['Group', f.group], ['Artists', f.artists.join(', ')],
                     ['Date', f.date], ['Width', f.width&.to_s], ['Colours', f.ice? ? 'iCE (16 backgrounds)' : nil]]
            ["#{t[:text_bright]}#{f.name}#{t[:text]}", "#{t[:accent]}#{f.credits}#{t[:text]}", '',
             *facts.reject { |_, v| v.to_s.empty? }.map { |k, v| "#{t[:label]}#{k.ljust(8)}#{t[:text]}#{v}" }, '',
             *BBS::FrameBuffer.wrap_ansi("#{t[:text_dim]}#{ctx[:app].gallery.file_url(f)}#{t[:text]}", width - 1)]
          end
          w.bottom_meta { |_f, _ctx| 'Enter shows it' }
          w.on_activate { |f, _window, ctx| ctx[:app].view_piece(f) }
          w.action(label: '&View') do |win, ctx|
            file = ctx[:app].selected(win)
            ctx[:app].view_piece(file) if file
            :keep
          end
        end

        window :wall, type: :master_detail do |w|
          w.maximizable true
          w.title         ' The Wall '
          w.height        { |ctx| ctx[:app].rows - 6 }
          w.list_width    { |ctx| [24, ctx[:app].cols - 46].max }
          w.items         { |ctx| ctx[:works] }
          w.item_label    { |work, _ctx| work.title }
          w.empty_message 'Nothing on the Wall yet: paint on the canvas and save it.'
          w.render_detail do |work, width, ctx|
            t = ctx[:app].theme
            picture = work.canvas
            ["#{t[:text_bright]}#{work.title}#{t[:text]}", "#{t[:accent]}#{work.handle}#{t[:text]} · #{work.date}", '',
             *CanvasModel::ROWS.times.map { |y| ArtLines.canvas(picture, y, 0, [width - 1, CanvasModel::COLS].min) }]
          end
          w.bottom_meta { |work, _ctx| "##{work.id}" }
          w.on_activate { |work, _window, ctx| ctx[:app].view_work(work) }
          w.action(label: '&View') do |win, ctx|
            work = ctx[:app].selected(win)
            ctx[:app].view_work(work) if work
            :keep
          end
          w.action(label: '&Reload') do |win, ctx|
            win.replace_items(ctx[:app].wall.all)
            :keep
          end
        end

        menubar do
          menu '&Gallery' do
            item '&16colo.rs years', shortcut: 'F2' do open_years end
            separator
            item '&Log off', shortcut: 'Alt-X' do :halt end
          end
          menu '&Canvas' do
            item '&Open the canvas', shortcut: 'F3' do open_canvas end
            item '&Save to the Wall', shortcut: 'Ctrl-S' do save_to_wall end
          end
          menu '&Wall' do
            item '&Show the Wall', shortcut: 'F4' do open_wall end
          end
          menu '&Help' do
            item '&About' do
              BBS::Dialogs.message(self,
                'Pixelia BBS — the PETSCII & ANSI art gallery of Teletype Games, powered by rubbs. The gallery is ' \
                'the 16colo.rs archive of the ANSI scene, read live from its public API. The canvas is one 40×25 ' \
                'picture that every caller paints on, from a Commodore 64 or from here, and both see it the same. ' \
                'Saved pictures go on the Wall.',
                title: ' About ', width: 64)
            end
            item '&Canvas keys' do
              BBS::Dialogs.message(self,
                'Arrows move · type to paint · Enter paints the brush · Backspace/Delete rub out · F7/F8 ink · ' \
                'F9 or Ctrl-R reverse (black on the ink: a space is a block of colour) · Insert or Ctrl-G glyph ' \
                'mode: the letters paint graphics (q w e / a s d / z x c are box corners, g █ t ▀ b ▄ y ▌ h ▐ u ▒) · ' \
                'Ctrl-S save to the Wall · Ctrl-Z undo · mouse: click to place, drag or right click to paint, ' \
                'click an ink or a brush in the panel. 20 cells a second at most.',
                title: ' Canvas keys ', width: 64)
            end
          end
        end

        status_hint('F2',  'Gallery') { open_years }
        status_hint('F3',  'Canvas') { open_canvas }
        status_hint('F4',  'Wall') { open_wall }
        status_hint('F10', 'Menu') { menubar.open(0) }
        status_hint('Alt-X', 'Bye') { :halt }

        on_tick { statusbar.right_text = status_text }

        init do
          logo = add(LogoWidget.new)
          logo.layout(1, 3, cols, LogoWidget::HEIGHT)
          desktop_label('F2  the ANSI gallery of 16colo.rs', :text, 1, 10, cols, align: :center)
          desktop_label('F3  the canvas everyone paints on ', :text, 1, 11, cols, align: :center)
          desktop_label('F4  the Wall of saved pictures   ', :text, 1, 12, cols, align: :center)
          desktop_label('─── classic 8-bit art and a canvas for your terminal or Commodore 64 ───', :text_dim,
                        1, rows - 2, cols, align: :center)
          statusbar.right_text = status_text
        end
      end

      BBS::Flow.define do
        call do |ctx, runner|
          app.run(session: runner.session, session_id: ctx[:session_id], context: ctx)
          bbs.canvas.leave(ctx[:session_id])
          nil
        end
        call do |_ctx, runner|
          BBS::Goodbye.modern(runner, title: 'Pixelia BBS')
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end
  end
end
