# frozen_string_literal: true

module UI
  module Modern
    module Windows
      # Messages > Mail: the letters of a registered name (and the Sysop box
      # for a sysop), with Write, Reply and Delete; and a letter to write.
      module Mail
        LETTER_ERRORS = {
          unknown:     'No registered name like that. Write to Sysop, or check the User Listing.',
          guest:       'A guest writes only to the Sysop. Register to write to others.',
          empty:       'The letter is empty.',
          too_fast:    "One letter every #{MailService::COOLDOWN} seconds, please.",
          daily_limit: 'That is all the feedback a guest can leave today. Register, or call again tomorrow.'
        }.freeze

        extend Section

        section :messages do
          window :mail, :master_detail do
            title      { "Mail — #{context[:username]}" }
            list_width 36
            empty      { Formatters::Mail.empty(registered?) }
            items      { inbox }
            label      { |letter| Formatters::Mail.label(letter) }
            detail do |letter, width|
              mail.mark_read(letter)
              Formatters::Mail.detail(letter, width)
            end
            meta { '• unread   Write · Reply · Delete' }
            action('Write', align: :left) { write_mail(on_sent: -> { window.replace_items(inbox) }) }
            action('Reply', align: :left) { |letter| reply_to(letter) }
            action('Delete', align: :left) do |letter|
              confirm("Delete the letter from #{letter.from}, \"#{letter.subject}\"?", title: 'Delete') do
                mail.delete(letter)
                window.replace_items(inbox)
              end
            end
          end

          # A letter to a registered name or the sysop.
          window :compose_mail, :form do
            maximizable  true
            title        'Write a Letter'
            width        { [cols - 8, 70].min }
            height       18
            hint         { "From: #{context[:username]} — to a registered name, or Sysop. Ctrl-Enter sends" }
            submit_label '&Send'
            cancel_label '&Cancel'
            prefill      { { to: extras[:to].to_s, subject: extras[:subject].to_s } }
            field :to,      label: 'To'
            field :subject, label: 'Subject', max_length: MailService::SUBJECT_MAX
            field :body,    type: :textarea, max_length: MailService::BODY_MAX
            on_submit do |values|
              result = board.send_letter(
                context[:username],
                values[:to],
                values[:subject],
                values[:body],
                registered: registered?,
                caller_key: caller_key
              )
              error!(LETTER_ERRORS.fetch(result, 'Call with a name to write letters.')) unless result == :ok
              extras[:on_sent]&.call
              message("Your letter is on its way to #{mail.recipient(values[:to])}.", title: 'Sent')
            end
          end
        end

        helpers do
          def inbox = mail.inbox(context[:username], sysop: sysop?)

          def reply_to(letter)
            subject = letter.subject.start_with?('Re: ') ? letter.subject : "Re: #{letter.subject}"
            write_mail(to: letter.from, subject: subject[0, MailService::SUBJECT_MAX])
          end
        end
      end
    end
  end
end
