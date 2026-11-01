# frozen_string_literal: true

module UI
  module Modern
    # The helpers of the Application: the services, opening the gallery's
    # windows, the canvas and the Wall, and showing a piece or a work.
    module Helpers
      def gallery = services[:gallery]

      def canvas = services[:canvas]

      def wall = services[:wall]

      # Who the Wall counts saves by: the caller's address, not the session.
      def caller_key = BBS::RateLimit.caller_key(session)

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
        else show_piece(file, art)
        end
      end

      def show_piece(file, art)
        title = [file.name, file.credits].reject(&:empty?).join(' · ')
        with_line do |session|
          Viewer.run(session, width: art.width, height: art.height, title: title) { |y, x, w| ArtLines.art(art, y, x, w) }
        end
      end

      def open_canvas
        window = switchable_windows.find { |w| w.is_a?(CanvasWindow) }
        return raise_window(window) if window

        open_window(CanvasWindow.new(self, canvas: canvas, who: session_id, on_save: -> { save_to_wall }))
      end

      def save_to_wall
        wait = wall.wait(caller_key)
        return wall_message(WallText.wait(wait)) if wait.positive?
        return wall_message(WallText.result(:blank_canvas)) if canvas.snapshot.empty?

        BBS::Windows::Form.open(self, title: ' Save to the Wall ', width: 52,
          hint: 'The canvas as it is now goes on the Wall. Alt-S saves.',
          fields: [{ key: :title, label: 'Title', max_length: WallService::MAX_TITLE },
                   { key: :handle, label: 'Handle', value: @handle.to_s, max_length: WallService::MAX_HANDLE }],
          submit_label: '&Save',
          on_submit: ->(values, form) { submit_work(values, form) })
      end

      def submit_work(values, form)
        result = wall.save(caller_key, title: values[:title], handle: values[:handle])
        unless result.is_a?(WorkModel)
          form.error(WallText.result(result))
          return :keep
        end

        @handle = result.handle
        wall_message(WallText.result(result))
        :close
      end

      def wall_message(text) = BBS::Dialogs.message(self, text, title: ' The Wall ')

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

      # Runs +action+ on the item picked in +window+, if any; the window stays.
      def with_selected(window)
        item = selected(window)
        yield item if item
        :keep
      end

      def status_text = "#{canvas.painters} painting │ #{Time.now.strftime('%H:%M')}"

      def desktop_label(text, style, x, y, width, align: :left)
        label = BBS::Widgets::Label.new(text: text, align: align, style_key: style)
        label.layout(x, y, width, 1)
        add(label)
      end
    end
  end
end
