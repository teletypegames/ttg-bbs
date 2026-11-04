# frozen_string_literal: true

module UI
  class Board < BBS::Petscii::Face
    # The editor's account on a call: logging in and changing the password.
    # The limits on tries are the EditorService's, counted by the name and
    # by the caller, so a new call does not start over.
    module Account
      LOGIN_ERRORS = { busy: 'The board is busy. Try again in a moment.', wrong: 'Wrong name or password.' }.freeze

      PASSWORD_WORDING = Hash.new('The password could not be changed.').merge(
        ok:             'Password changed.',
        differ:         'The two new ones differ.',
        wrong:          'The current password is wrong.',
        short_password: "The new password needs at least #{EditorService::MIN_PASS} characters.",
        busy:           'The board is busy. Try again in a moment.'
      ).freeze

      private

      def login
        title('EDITOR LOGIN', right)
        name = prompt('name', hint: 'For the editors of the blog. Return alone: back.', max: EditorService::MAX_NAME)
        return unless name

        logged_in(name, locked?(name) ? :locked : editors.login(name, secret('password').to_s, caller: caller_key))
      end

      def locked?(name) = editors.locked_for(name, caller_key).positive?

      def secret(label) = prompt(label, mask: '*', max: 200)

      # What a login came to: the editor in, or why not.
      def logged_in(name, result)
        return alert(refusal(name, result)) if result.is_a?(Symbol)

        context[:user] = result
        notice("Welcome, #{result.name}. Open a post to edit it, or write a new one.")
      end

      def refusal(name, result)
        return LOGIN_ERRORS.fetch(result) unless result == :locked

        minutes = (editors.locked_for(name, caller_key) / 60).ceil
        "Too many failed tries. Try again in #{minutes} minute#{'s' unless minutes == 1}."
      end

      def password
        title('CHANGE PASSWORD', right)
        say("At least #{EditorService::MIN_PASS} characters. Return alone: back.", color: GR)
        old = secret('current')
        return unless old

        fresh = secret('new').to_s
        again = secret('again').to_s
        report(fresh == again ? editors.change_password(user.name, old, fresh) : :differ, PASSWORD_WORDING)
      end
    end
  end
end
