# frozen_string_literal: true

module UI
  module Modern
    # The title of a picture that came in by XMODEM (+upload+, a
    # PetsciiModel the Exhibition took), under the caller's name.
    module UploadWindow
      extend Rubbs::Modern::Part

      window :upload_work, :form do
        title        'Upload to the Exhibition'
        width        56
        hint         -> { "#{Wording.arrived(upload)} Alt-S hangs it." }
        field        :title, label: 'Title', max_length: ExhibitionService::MAX_TITLE
        submit_label '&Hang'
        on_submit do |values|
          work = exhibition.hang(
            caller_key,
            title:   values[:title],
            handle:  identity.name.to_s,
            picture: upload,
            actor:   Rubbs::Common::Central::Actor.of(session)
          )
          error!(Wording.result(work)) unless work.is_a?(WorkModel)
          message(Wording.result(work), title: 'The Exhibition')
        end
      end
    end
  end
end
