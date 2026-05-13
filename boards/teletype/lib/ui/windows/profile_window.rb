# frozen_string_literal: true

module UI
  module Windows
    module_function

    def profile(app, services:)
      username = app.context[:username] || 'Anonymous'
      existing = services[:profile].find(username) || {}
      BBS::Windows::Form.open(app,
        title: " Profile — #{username} ",
        width: 64, height: 14,
        fields: [
          { key: :signature, label: 'Signature', value: existing['signature'].to_s },
          { key: :location,  label: 'Location',  value: existing['location'].to_s },
          { key: :homepage,  label: 'Homepage',  value: existing['homepage'].to_s },
          { key: :notes,     label: 'Notes',     value: existing['notes'].to_s }
        ],
        on_submit: ->(values, _form) {
          services[:profile].update(username,
            signature: values[:signature],
            location:  values[:location],
            homepage:  values[:homepage],
            notes:     values[:notes]
          )
          BBS::Dialogs.message(app, 'Profile saved.', title: ' Saved ')
        }
      )
    end
  end
end
