# frozen_string_literal: true

module UI
  class Petscii < Rubbs::Petscii::Face
    # The Exhibition on a C64: the works newest first as a numbered cursor
    # list, and a work on the whole screen, as it was painted (a canvas work
    # with CRSR down for its last row, a PETSCII work on the C64's own
    # screen, WorkScreen); and the upload of a TTG Canvas 64 picture by
    # XMODEM.
    module Exhibition
      private

      def exhibition_list
        each_pick(
          'THE EXHIBITION',
          -> { exhibition.all },
          empty: 'nothing on the exhibition yet: paint on the canvas and save it.',
          right: -> { "#{exhibition.all.size} works" },
          label: ->(w) { "#{w.title} #{GR}#{w.handle}#{LG}" }
        ) { |work| work.petscii? ? show_petscii(work) : show_work(work) }
      end

      def show_work(work)
        view   = CanvasView.new(session)
        canvas = work.canvas
        loop do
          view.sync(canvas)
          view.status([[" #{work.title[0, 18]}", 1], [" #{work.handle[0, 10]}", 3], [' ret', 7]])
          view.place(0, view.offset)
          case key
          when :down then view.follow?(CanvasModel::ROWS - 1)
          when :up then view.follow?(0)
          else return
          end
        end
      end

      # A PETSCII work on the whole screen until a key; then the face's
      # lowercase set again.
      def show_petscii(work)
        session.write_raw(WorkScreen.bytes(work.petscii))
        key
        session.write_raw([Rubbs::Petscii::Canvas::LOWERCASE, Rubbs::Petscii::Canvas::CLEAR].pack('C*'))
      end

      # A TTG Canvas 64 picture by XMODEM, judged, then hung under a title.
      def exhibition_upload
        title('UPLOAD TO THE EXHIBITION')
        return alert(Wording::ACCOUNT) unless session.identity.signed_in?

        wait = exhibition.wait(caller_key)
        return alert(Wording.wait(wait)) if wait.positive?

        picture = receive_picture or return
        say(Wording.arrived(picture), color: GR)
        puts
        name = Rubbs::Common::Screens::Field.ask(session, " #{WH}title#{LG}  ", max: ExhibitionService::MAX_TITLE) or return
        puts
        say(Wording.result(hang(picture, name)), color: WH)
        pause
      end

      # The picture the caller sends, or nil after saying why there is none.
      def receive_picture
        say(Wording::UPLOAD, color: GR)
        puts
        say(Rubbs::Common::Files::Transfer.upload_start(Wording::UPLOAD_WHAT), color: WH)
        puts
        data = Rubbs::Common::Files::Transfer.receive(session, max_bytes: ExhibitionService::MAX_UPLOAD)
        title('UPLOAD TO THE EXHIBITION')
        picture = data.is_a?(String) ? exhibition.accept(data) : nil
        return picture if picture.is_a?(PetsciiModel)

        alert(picture ? Wording.refusal(picture) : Rubbs::Common::Files::Transfer.upload_result(data))
        nil
      end

      def hang(picture, name)
        exhibition.hang(
          caller_key,
          title:   name,
          handle:  session.identity.name.to_s,
          picture: picture,
          actor:   Rubbs::Common::Central::Actor.of(session)
        )
      end
    end
  end
end
