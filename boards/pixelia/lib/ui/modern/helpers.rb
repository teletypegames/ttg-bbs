# frozen_string_literal: true

module UI
  module Modern
    # What the caller does on the modern face: the gallery's windows, a piece
    # or a work on the whole screen, the canvas and saving it to the Exhibition.
    module Helpers
      NO_ANSWER = '16colo.rs did not answer. Try again later.'
      PIECE     = { too_big: 'This piece is too large for the board.', unavailable: NO_ANSWER }.freeze

      def open_years
        show(:years, years: loading('Reading 16colo.rs…', failed: NO_ANSWER) { gallery.years })
      end

      def open_year(year)
        show(:packs, year: year, packs: loading("Reading the packs of #{year.year}…", failed: NO_ANSWER) { gallery.packs(year) })
      end

      def open_pack(pack)
        show(:files, pack: pack, files: loading("Reading #{pack.name}…", failed: NO_ANSWER) { gallery.files(pack) })
      end

      def view_piece(file)
        art = loading("Fetching #{file.name}…") { gallery.piece(file) }
        return report(art, PIECE, title: 'Piece') if art.is_a?(Symbol)

        title = [file.name, file.credits].reject(&:empty?).join(' · ')
        with_line do |session|
          Viewer.run(session, width: art.width, height: art.height, title: title) { |y, x, w| ArtLines.art(art, y, x, w) }
        end
      end

      def view_work(work)
        return view_petscii(work) if work.petscii?

        picture = work.canvas
        with_line do |session|
          Viewer.run(
            session,
            width:  CanvasModel::COLS,
            height: CanvasModel::ROWS,
            title:  "#{work.title} · #{work.handle} · #{work.date}"
          ) do |y, x, w|
            ArtLines.canvas(picture, y, x, w)
          end
        end
      end

      # A PETSCII work on the whole screen, framed in its border colour.
      def view_petscii(work)
        picture = work.petscii
        with_line do |session|
          Viewer.run(
            session,
            width:  ArtLines::FRAMED_COLS,
            height: ArtLines::FRAMED_ROWS,
            title:  "#{work.title} · #{work.handle} · #{work.date}"
          ) do |y, x, w|
            ArtLines.petscii_framed(picture, y, x, w)
          end
        end
      end

      # A TTG Canvas 64 picture by XMODEM; the form for its title when the
      # Exhibition takes it.
      def upload_to_exhibition
        return message(Wording::ACCOUNT, title: 'The Exhibition') unless signed_in?

        wait = exhibition.wait(caller_key)
        return message(Wording.wait(wait), title: 'The Exhibition') if wait.positive?

        data = with_line { |session| receive_upload(session) }
        picture = data.is_a?(String) ? exhibition.accept(data) : nil
        return show(:upload_work, upload: picture) if picture.is_a?(PetsciiModel)

        text = picture ? Wording.refusal(picture) : Rubbs::Common::Files::Transfer.upload_result(data)
        message(text, title: 'Upload', width: 64)
      end

      def open_canvas
        window = windows.grep(CanvasWindow).first
        return raise_window(window) if window

        show(CanvasWindow.new(self, canvas: canvas, who: session_id, on_save: -> { save_to_exhibition }))
      end

      def save_to_exhibition
        return message(Wording::ACCOUNT, title: 'The Exhibition') unless signed_in?

        wait = exhibition.wait(caller_key)
        return message(Wording.wait(wait), title: 'The Exhibition') if wait.positive?
        return message(Wording.result(:blank_canvas), title: 'The Exhibition') if canvas.snapshot.empty?

        show(:save_work)
      end

      # The board's wall (ttg-common TTG::Wall): callers talk about the art.
      def wall = with_line { TTG::Wall.open(@session) }

      # Something for the sysops (ttg-common TTG::Feedback).
      def feedback = with_line { TTG::Feedback.open(@session) }

      def open_exhibition = show(:exhibition, works: exhibition.all)

      private

      def receive_upload(session)
        words = [Wording::UPLOAD, '', Rubbs::Common::Files::Transfer.upload_start(Wording::UPLOAD_WHAT)]
        lines = words.flat_map { |w| w.empty? ? [''] : Rubbs::Modern::FrameBuffer.wrap_ansi(w, cols - 4) }
        session.write("\r\n#{lines.map { |l| "  #{l}\r\n" }.join}\r\n")
        Rubbs::Common::Files::Transfer.receive(session, max_bytes: ExhibitionService::MAX_UPLOAD)
      end
    end
  end
end
