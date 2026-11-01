# frozen_string_literal: true

module UI
  module Modern
    # The form that writes to the admins.
    module FeedbackWindow
      module_function

      def install(app)
        app.window(:feedback, type: :form) { |w| configure(w) }
      end

      def configure(w)
        w.title ' Feedback to the admins '
        w.width 70
        w.hint  'A bug, an idea, a word of thanks: write it below. Alt-S sends.'
        w.field :from, label: 'Your name', max_length: InboxService::MAX_FIELD, placeholder: 'optional'
        w.field :text, type: :textarea, rows: 8, max_length: InboxService::MAX_TEXT
        w.submit_label '&Send'
        w.on_submit { |values, form, ctx| submit(values, form, ctx) }
      end

      def submit(values, form, ctx)
        case ctx[:inbox].feedback(caller: ctx[:app].caller_key, **values)
        when :ok      then ctx[:app].sent; :close
        when :limited then ctx[:app].limited; :close
        when :empty   then form.error('Write something first.'); :keep
        else form.error('The message could not be saved. Try again later.'); :keep
        end
      end
    end
  end
end
