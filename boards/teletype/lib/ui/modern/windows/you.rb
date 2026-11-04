# frozen_string_literal: true

module UI
  module Modern
    module Windows
      # You: registering the name, the profile, the stats and the Sysop
      # Console.
      module You
        PROFILE = %i[signature location homepage notes].freeze

        extend Section

        section :you do
          # The name called with, tied to a password.
          window :register, :form do
            title        { "Register — #{caller_name}" }
            width        60
            height       11
            hint         'Next time the BBS asks for this password.'
            submit_label '&Register'
            cancel_label '&Cancel'
            field :password, label: 'Password', password: true
            field :confirm,  label: 'Again',    password: true
            errors Wording::REGISTER
            on_submit do |values|
              result = members.register(caller_name, values[:password], values[:confirm])
              next result unless result.is_a?(BBS::Auth::Identity)

              session.identity = result
              message("#{result.name} is yours now.", title: 'Registered')
            end
          end

          window :profile, :form do
            title   { "Profile — #{caller_name}" }
            width   64
            height  14
            prefill { PROFILE.to_h { |key| [key, (profile.find(caller_name) || {})[key].to_s] } }
            PROFILE.each { |key| field key, label: key.to_s.capitalize }
            on_submit do |values|
              profile.update(caller_name, **values)
              message('Profile saved.', title: 'Saved')
            end
          end

          window :my_stats, :info do
            title  { "Your Stats — #{caller_name}" }
            width  60
            height 16
            body do
              Formatters::MyStats.body(**board.my_stats(
                caller_name,
                registered:    registered?,
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
                username:         caller_name,
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
