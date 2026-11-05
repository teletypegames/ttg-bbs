# frozen_string_literal: true

module UI
  module Modern
    # The form that writes to the admins.
    module FeedbackWindow
      extend Rubbs::Modern::Part

      window :feedback, :form do
        title 'Feedback to the admins'
        width 70
        hint  'A bug, an idea, a word of thanks: write it below. Alt-S sends.'
        field :from, label: 'Your name', max_length: InboxService::MAX_FIELD, placeholder: 'optional'
        field :text, type: :textarea, rows: 8, max_length: InboxService::MAX_TEXT
        submit_label '&Send'
        errors empty: 'Write something first.', failed: 'The message could not be saved. Try again later.'
        on_submit { |values| answer(inbox.feedback(caller: caller_key, **values)) }
      end
    end
  end
end
