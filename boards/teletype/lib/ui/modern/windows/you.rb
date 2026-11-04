# frozen_string_literal: true

module UI
  module Modern
    module Windows
      # You: registering the name, the profile, the stats and the Sysop
      # Console.
      module You
        REGISTER_ERRORS = {
          anonymous:  'Log in with a name first, not as Anonymous.',
          reserved:   'This name is reserved for the sysop.',
          taken:      'This name is already registered.',
          look_alike: 'This name looks too much like a registered one.',
          too_short:  "At least #{AccountService::MIN_PASSWORD} characters.",
          mismatch:   'The two passwords differ.'
        }.freeze
        PROFILE = %i[signature location homepage notes].freeze

        extend Section

        section :you do
          # The name called with, tied to a password.
          window :register, :form do
            title        { "Register — #{context[:username]}" }
            width        60
            height       11
            hint         'Next time the BBS asks for this password.'
            submit_label '&Register'
            cancel_label '&Cancel'
            field :password, label: 'Password', password: true
            field :confirm,  label: 'Again',    password: true
            errors REGISTER_ERRORS
            on_submit do |values|
              result = accounts.register(context[:username], values[:password], values[:confirm])
              next result unless result == :ok

              context[:authenticated] = true
              message("#{context[:username]} is yours now.", title: 'Registered')
            end
          end

          window :profile, :form do
            title   { "Profile — #{caller_name}" }
            width   64
            height  14
            prefill { PROFILE.to_h { |key| [key, (profile.find(caller_name) || {})[key].to_s] } }
            PROFILE.each { |key| field key, label: key.to_s.capitalize }
            on_submit do |values|
              profile.update(context[:username], **values)
              message('Profile saved.', title: 'Saved')
            end
          end

          window :my_stats, :info do
            title  { "Your Stats — #{context[:username]}" }
            width  60
            height 16
            body do
              Formatters::MyStats.body(**board.my_stats(
                caller_name,
                registered:    context[:authenticated],
                session_id:    session_id,
                caller_number: context[:caller_number],
                sysop:         sysop?
              ))
            end
          end

          # The board at a glance and the broadcast.
          window :sysop_console, :info do
            title  'Sysop Console'
            width  70
            height 18
            scroll true
            body do
              Formatters::Sysop.console_body(
                username:         context[:username],
                online_count:     online.count,
                total_messages:   boards.total_count,
                chat_subscribers: chat.subscriber_count,
                online_users:     online.user_list,
                recent_callers:   last_callers.recent(5)
              )
            end
            button('Broadcast', align: :left) do
              sysop_broadcast
              keep
            end
            button 'Close', cancel: true
          end
        end
      end
    end
  end
end
