# frozen_string_literal: true

module UI
  module Modern
    # The canvas as it is now to the Exhibition, under a title and the caller's
    # name (their account of the network).
    module SaveWindow
      extend Rubbs::Modern::Part

      window :save_work, :form do
        title        'Save to the Exhibition'
        width        52
        hint         'The canvas as it is now goes on the Exhibition. Alt-S saves.'
        field        :title, label: 'Title', max_length: ExhibitionService::MAX_TITLE
        submit_label '&Save'
        on_submit do |values|
          work = exhibition.save(caller_key, title: values[:title], handle: identity.name.to_s)
          error!(Wording.result(work)) unless work.is_a?(WorkModel)
          message(Wording.result(work), title: 'The Exhibition')
        end
      end
    end
  end
end
