# frozen_string_literal: true

module UI
  module Modern
    # The form for a new tip. TipService decides whether it goes in; the form
    # says what it decided.
    module AddTipWindow
      extend BBS::Part

      window :add_tip, :form do
        title { "A tip for #{game.title}" }
        width 70
        hint  "Up to #{TipService::MAX_TEXT} characters; an admin reads it first. Alt-S sends."
        field :handle, label: 'Your handle', max_length: TipService::MAX_HANDLE, placeholder: 'optional'
        field :text, type: :textarea, rows: 6, max_length: TipService::MAX_TEXT
        submit_label '&Send'
        errors Wording::TIP.except(:ok)
        on_submit do |values|
          result = tips.submit(game, text: values[:text], handle: values[:handle], caller: caller_key)
          note(Wording::TIP[:ok], 'Thanks') if result == :ok
          result
        end
      end
    end
  end
end
