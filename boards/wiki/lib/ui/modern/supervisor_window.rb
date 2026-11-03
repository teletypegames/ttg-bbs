# frozen_string_literal: true

module UI
  module Modern
    # The supervisor login: the password unlocks the private pages for this
    # call. SupervisorService decides; the form only says what it decided.
    module SupervisorWindow
      extend BBS::Part

      window :supervisor_login, :form do
        title        'Supervisor login'
        width        46
        hint         'Enter the supervisor password:'
        field        :password, label: 'Password', password: true
        submit_label '&Unlock'
        errors       Wording::UNLOCK
        on_submit do |values|
          result = supervisor.unlock(values[:password])
          result == :granted ? unlock : result
        end
      end
    end
  end
end
