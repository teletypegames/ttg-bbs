# frozen_string_literal: true

module UI
  module Modern
    module Windows
      # You > Register: the name called with, tied to a password.
      module Register
        ERRORS = {
          anonymous:  'Log in with a name first, not as Anonymous.',
          reserved:   'This name is reserved for the sysop.',
          taken:      'This name is already registered.',
          look_alike: 'This name looks too much like a registered one.',
          too_short:  "At least #{AccountService::MIN_PASSWORD} characters.",
          mismatch:   'The two passwords differ.'
        }.freeze

        def self.configure(w)
          w.accent Accent::STYLES[:you]
          w.title        { |ctx| Icon.title(:you, "Register — #{ctx[:username]}") }
          w.width        60
          w.height       11
          w.hint         'Next time the BBS asks for this password.'
          w.submit_label '&Register'
          w.cancel_label '&Cancel'
          w.field :password, label: 'Password', password: true
          w.field :confirm,  label: 'Again',    password: true
          w.on_submit { |values, form, ctx| submit(values, form, ctx) }
        end

        def self.submit(values, form, ctx)
          result = ctx[:accounts].register(ctx[:username], values[:password], values[:confirm])
          return Windows.refuse(form, ERRORS[result]) unless result == :ok

          ctx[:app].context[:authenticated] = true
          BBS::Dialogs.message(ctx[:app], "#{ctx[:username]} is yours now.", title: ' Registered ')
          :close
        end
      end

      # You > Profile.
      module Profile
        FIELDS = %i[signature location homepage notes].freeze

        def self.configure(w)
          w.accent Accent::STYLES[:you]
          w.title  { |ctx| Icon.title(:you, "Profile — #{ctx[:username] || AccountService::ANONYMOUS}") }
          w.width  64
          w.height 14
          w.prefill { |ctx| prefill(ctx[:profile].find(ctx[:username] || AccountService::ANONYMOUS) || {}) }
          FIELDS.each { |field| w.field field, label: field.to_s.capitalize }
          w.on_submit do |values, _form, ctx|
            ctx[:profile].update(ctx[:username], **values)
            BBS::Dialogs.message(ctx[:app], 'Profile saved.', title: ' Saved ')
            :close
          end
        end

        def self.prefill(existing) = FIELDS.to_h { |field| [field, existing[field.to_s].to_s] }
      end

      # You > Your Stats.
      module MyStats
        def self.configure(w)
          w.accent Accent::STYLES[:you]
          w.title  { |ctx| Icon.title(:you, "Your Stats — #{ctx[:username]}") }
          w.width  60
          w.height 16
          w.body   { |ctx| Formatters::MyStats.body(**stats(ctx)) }
        end

        def self.stats(ctx)
          ctx[:bbs].my_stats(ctx[:username] || AccountService::ANONYMOUS, registered: ctx[:authenticated],
                                                                          session_id: ctx[:app].session_id,
                                                                          caller_number: ctx[:caller_number],
                                                                          sysop: ctx[:app].sysop?)
        end
      end

      # You > Sysop Console: the board at a glance and the broadcast.
      module SysopConsole
        def self.configure(w)
          w.accent Accent::STYLES[:you]
          w.title  Icon.title(:you, 'Sysop Console')
          w.width  70
          w.height 18
          w.scroll true
          w.body   { |ctx| body(ctx) }
          w.button label: '&Broadcast', align: :left do |_window, ctx|
            ctx[:app].sysop_broadcast
            :keep
          end
          w.button label: '&Close', cancel: true
        end

        def self.body(ctx)
          Formatters::Sysop.console_body(username: ctx[:username], online_count: ctx[:online].count,
                                         total_messages: ctx[:boards].total_count,
                                         chat_subscribers: ctx[:chat].subscriber_count,
                                         online_users: ctx[:online].user_list,
                                         recent_callers: ctx[:last_callers].recent(5))
        end
      end
    end
  end
end
