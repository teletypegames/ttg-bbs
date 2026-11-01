# frozen_string_literal: true

module UI
  module Modern
    module Windows
      # Messages > Mail: the letters of a registered name (and the Sysop box
      # for a sysop), with Write, Reply and Delete.
      module Mail
        def self.configure(w)
          w.accent Accent::STYLES[:messages]
          w.maximizable true
          w.title         { |ctx| Icon.title(:messages, "Mail — #{ctx[:username]}") }
          w.list_width    36
          w.empty_message { |ctx| Formatters::Mail.empty(ctx[:authenticated]) }
          w.items         { |ctx| inbox(ctx) }
          w.item_label    { |letter, _ctx| Formatters::Mail.label(letter) }
          w.render_detail { |letter, width, ctx| detail(letter, width, ctx) }
          actions(w)
        end

        def self.actions(w)
          w.bottom_meta { |_letter, _ctx| '• unread   Write · Reply · Delete' }
          w.action(label: '&Write', align: :left) { |window, ctx| write(window, ctx) }
          w.action(label: '&Reply', align: :left) { |window, ctx| reply(window.list_widget.selected_item, ctx) }
          w.action(label: '&Delete', align: :left) { |window, ctx| delete(window, ctx) }
        end

        def self.inbox(ctx) = ctx[:mail].inbox(ctx[:username], sysop: ctx[:app].sysop?)

        def self.detail(letter, width, ctx)
          ctx[:mail].mark_read(letter)
          Formatters::Mail.detail(letter, width)
        end

        def self.write(window, ctx)
          ctx[:app].write_mail(on_sent: -> { window.replace_items(inbox(ctx)) })
          :keep
        end

        def self.reply(letter, ctx)
          if letter
            subject = letter.subject.start_with?('Re: ') ? letter.subject : "Re: #{letter.subject}"
            ctx[:app].write_mail(to: letter.from, subject: subject[0, MailService::SUBJECT_MAX])
          end
          :keep
        end

        def self.delete(window, ctx)
          letter = window.list_widget.selected_item
          if letter
            BBS::Dialogs.confirm(ctx[:app], "Delete the letter from #{letter.from}, \"#{letter.subject}\"?",
                                 title: ' Delete ', on_yes: lambda {
                                   ctx[:mail].delete(letter)
                                   window.replace_items(inbox(ctx))
                                 })
          end
          :keep
        end
      end

      # A letter to a registered name or the sysop.
      module ComposeMail
        ERRORS = {
          unknown:     'No registered name like that. Write to Sysop, or check the User Listing.',
          guest:       'A guest writes only to the Sysop. Register to write to others.',
          empty:       'The letter is empty.',
          too_fast:    "One letter every #{MailService::COOLDOWN} seconds, please.",
          daily_limit: 'That is all the feedback a guest can leave today. Register, or call again tomorrow.'
        }.freeze

        def self.configure(w)
          w.accent Accent::STYLES[:messages]
          w.maximizable true
          w.title        Icon.title(:messages, 'Write a Letter')
          w.width        { |ctx| [ctx[:app].cols - 8, 70].min }
          w.height       18
          w.hint         { |ctx| "From: #{ctx[:username]} — to a registered name, or Sysop. Ctrl-Enter sends" }
          w.submit_label '&Send'
          w.cancel_label '&Cancel'
          fields(w)
          w.on_submit { |values, form, ctx| submit(values, form, ctx) }
        end

        def self.fields(w)
          w.prefill { |ctx| { to: ctx[:to].to_s, subject: ctx[:subject].to_s } }
          w.field :to,      label: 'To'
          w.field :subject, label: 'Subject', max_length: MailService::SUBJECT_MAX
          w.field :body,    type: :textarea, max_length: MailService::BODY_MAX
        end

        def self.submit(values, form, ctx)
          result = ctx[:bbs].send_letter(ctx[:username], values[:to], values[:subject], values[:body],
                                         registered: ctx[:authenticated], caller_key: ctx[:caller_key])
          return Windows.refuse(form, ERRORS.fetch(result, 'Call with a name to write letters.')) unless result == :ok

          ctx[:on_sent]&.call
          BBS::Dialogs.message(ctx[:app], "Your letter is on its way to #{ctx[:mail].recipient(values[:to])}.",
                               title: ' Sent ')
          :close
        end
      end
    end
  end
end
