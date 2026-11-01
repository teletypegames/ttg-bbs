# frozen_string_literal: true

module UI
  module Modern
    # The supervisor login: the password unlocks the private pages for this
    # call. SupervisorService decides; the form only says what it decided.
    module SupervisorWindow
      ERRORS = { unconfigured: 'No supervisor password configured.',
                 locked:       'Too many wrong passwords. Try again later.',
                 wrong:        'Wrong password.' }.freeze

      module_function

      def install(app)
        app.window(:supervisor_login, type: :form) { |w| configure(w) }
      end

      def configure(w)
        w.title ' Supervisor login '
        w.width 46
        w.hint 'Enter the supervisor password:'
        w.field :password, label: 'Password', password: true
        w.submit_label '&Unlock'
        w.on_submit { |values, form, ctx| submit(values[:password], form, ctx) }
      end

      def submit(password, form, ctx)
        result = ctx[:supervisor].unlock(password)
        return unlock(ctx[:app]) if result == :granted
        form.error(ERRORS.fetch(result, ERRORS[:wrong]))
        :keep
      end

      def unlock(app)
        app.context[:unlocked] = true
        app.windows.grep(BBS::Windows::MasterDetail).each(&:reload_detail)
        BBS::Dialogs.message(app, 'Supervisor access granted.', title: ' Unlocked ')
        :close
      end
    end
  end
end
