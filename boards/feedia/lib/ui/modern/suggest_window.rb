# frozen_string_literal: true

module UI
  module Modern
    # The form that suggests a feed to the admins.
    module SuggestWindow
      module_function

      def install(app)
        app.window(:suggest, type: :form) { |w| configure(w) }
      end

      def configure(w)
        w.title ' Suggest a feed '
        w.width 70
        w.hint  'Why this feed? Write it in the box below (optional). Alt-S sends.'
        w.field :url,  label: 'Feed address', max_length: InboxService::MAX_FIELD, placeholder: 'https://…'
        w.field :name, label: 'Its name', max_length: InboxService::MAX_FIELD
        w.field :from, label: 'Your name', max_length: InboxService::MAX_FIELD, placeholder: 'optional'
        w.field :note, type: :textarea, rows: 4, max_length: InboxService::MAX_TEXT
        w.submit_label '&Send'
        w.on_submit { |values, form, ctx| submit(values, form, ctx) }
      end

      def submit(values, form, ctx)
        case ctx[:inbox].suggest(caller: ctx[:app].caller_key, **values)
        when :ok      then ctx[:app].sent; :close
        when :limited then ctx[:app].limited; :close
        when :no_url  then form.error('The address of the feed, please.'); :keep
        when :bad_url then form.error('That is not an http:// or https:// address.'); :keep
        else form.error('The message could not be saved. Try again later.'); :keep
        end
      end
    end
  end
end
