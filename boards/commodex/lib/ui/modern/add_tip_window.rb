# frozen_string_literal: true

module UI
  module Modern
    # The form for a new tip. TipService decides whether it goes in; the
    # form says what it decided.
    module AddTipWindow
      module_function

      def install(app)
        app.window(:add_tip, type: :form) { |w| configure(w) }
      end

      def configure(w)
        w.title { |ctx| " A tip for #{ctx[:game].title} " }
        w.width 70
        w.hint  "Up to #{TipService::MAX_TEXT} characters; an admin reads it first. Alt-S sends."
        w.field :handle, label: 'Your handle', max_length: TipService::MAX_HANDLE, placeholder: 'optional'
        w.field :text, type: :textarea, rows: 6, max_length: TipService::MAX_TEXT
        w.submit_label '&Send'
        w.on_submit { |values, form, ctx| submit(ctx[:app], ctx[:game], values, form) }
      end

      def submit(app, game, values, form)
        result = app.tip_service.submit(game, text: values[:text], handle: values[:handle], caller: app.caller_key)
        if result == :ok
          app.note(Words.tip(result), ' Thanks ')
          :close
        else
          form.error(Words.tip(result))
          :keep
        end
      end
    end
  end
end
