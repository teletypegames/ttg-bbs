# frozen_string_literal: true

module UI
  module Windows
    module_function

    def profile(app, services:)
      username = app.context[:username] || 'Anonymous'
      existing = services[:profile].find(username) || {}

      w = 64
      h = 14
      window = BBS::Dialogs.centred_window(app, width: w, height: h,
                                          title: " Profile — #{username} ")

      fields = [
        [:signature, 'Signature', existing['signature']],
        [:location,  'Location',  existing['location']],
        [:homepage,  'Homepage',  existing['homepage']],
        [:notes,     'Notes',     existing['notes']],
      ]

      inputs = {}
      fields.each_with_index do |(key, label, value), i|
        l = BBS::Widgets::Label.new(text: label, style_key: :input_label)
        l.layout(window.bounds.x + 2, window.bounds.y + 1 + i * 2, 12, 1)
        window.add(l)

        input = BBS::Widgets::TextInput.new(value: value.to_s)
        input.layout(window.bounds.x + 14, window.bounds.y + 1 + i * 2, w - 18, 1)
        window.add(input)
        inputs[key] = input
      end

      save = BBS::Widgets::Button.new(
        label: '&Save',
        on_click: lambda do |_|
          services[:profile].update(username,
            signature: inputs[:signature].value,
            location:  inputs[:location].value,
            homepage:  inputs[:homepage].value,
            notes:     inputs[:notes].value
          )
          app.close_window(window)
          BBS::Dialogs.message(app, 'Profile saved.', title: ' Saved ')
        end
      )
      save.layout(window.bounds.x + w - 22, window.bounds.y + h - 2, 9, 1)
      window.add(save)

      cancel = BBS::Widgets::Button.new(label: '&Cancel',
                                        on_click: ->(_) { app.close_window(window) })
      cancel.layout(window.bounds.x + w - 12, window.bounds.y + h - 2, 10, 1)
      window.add(cancel)

      window.reset_focus
      window.focus_manager.focus(inputs[:signature])
      app.open_window(window)
      window
    end
  end
end
