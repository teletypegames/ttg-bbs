# frozen_string_literal: true

module UI
  module Modern
    # The canvas as it is now to the Wall, under a title and the caller's
    # handle (the last one they saved under).
    module SaveWindow
      extend BBS::Part

      window :save_work, :form do
        title        'Save to the Wall'
        width        52
        hint         'The canvas as it is now goes on the Wall. Alt-S saves.'
        field        :title, label: 'Title', max_length: WallService::MAX_TITLE
        field        :handle, label: 'Handle', value: -> { handle }, max_length: WallService::MAX_HANDLE
        submit_label '&Save'
        on_submit do |values|
          work = wall.save(caller_key, title: values[:title], handle: values[:handle])
          error!(Wording.result(work)) unless work.is_a?(WorkModel)
          context[:handle] = work.handle
          message(Wording.result(work), title: 'The Wall')
        end
      end
    end
  end
end
