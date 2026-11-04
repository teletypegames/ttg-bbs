# frozen_string_literal: true

module UI
  module Modern
    # The form that suggests a feed to the admins.
    module SuggestWindow
      extend BBS::Part

      window :suggest, :form do
        title 'Suggest a feed'
        width 70
        hint  'Why this feed? Write it in the box below (optional). Alt-S sends.'
        field :url,  label: 'Feed address', max_length: InboxService::MAX_FIELD, placeholder: 'https://…'
        field :name, label: 'Its name', max_length: InboxService::MAX_FIELD
        field :from, label: 'Your name', max_length: InboxService::MAX_FIELD, placeholder: 'optional'
        field :note, type: :textarea, rows: 4, max_length: InboxService::MAX_TEXT
        submit_label '&Send'
        errors no_url:  'The address of the feed, please.',
               bad_url: 'That is not an http:// or https:// address.',
               failed:  'The message could not be saved. Try again later.'
        on_submit { |values| answer(inbox.suggest(caller: caller_key, **values)) }
      end
    end
  end
end
