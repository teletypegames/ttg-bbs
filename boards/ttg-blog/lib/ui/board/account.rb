# frozen_string_literal: true

module UI
  class Board
    # The editor's account on a call: logging in and changing the password.
    # The limits on tries are the EditorService's, counted by the name and
    # by the caller, so a new call does not start over.
    module Account
      LOGIN_ERRORS = {
        busy:  'The board is busy. Try again in a moment.',
        wrong: 'Wrong name or password.'
      }.freeze

      PASSWORD_ERRORS = {
        wrong:          'The current password is wrong.',
        short_password: "The new password needs at least #{EditorService::MIN_PASS} characters.",
        busy:           'The board is busy. Try again in a moment.'
      }.freeze

      private

      def login
        @screen.title('EDITOR LOGIN', right)
        @screen.say('For the editors of the blog. Return alone: back.', GR)
        @screen.puts
        name = @screen.ask(" #{WH}name#{LG}> ", max: EditorService::MAX_NAME)
        return if name.empty?

        logged_in(name, locked?(name) ? :locked : try_password(name))
        @screen.pause
      end

      def locked?(name) = @editors.locked_for(name, caller_key).positive?

      def try_password(name)
        pass = @screen.ask(" #{WH}password#{LG}> ", mask: '*', max: 200)
        @screen.puts
        @editors.login(name, pass, caller: caller_key)
      end

      # What a login came to: the editor in, or why not.
      def logged_in(name, result)
        return @screen.say(refusal(name, result), RD) if result.is_a?(Symbol)

        @ctx[:user] = result
        @screen.say("Welcome, #{result.name}. Open a post to edit it, or write a new one.", GN)
      end

      def refusal(name, result)
        return LOGIN_ERRORS.fetch(result) unless result == :locked

        minutes = (@editors.locked_for(name, caller_key) / 60).ceil
        "Too many failed tries. Try again in #{minutes} minute#{'s' unless minutes == 1}."
      end

      def password
        @screen.title('CHANGE PASSWORD', right)
        @screen.say("At least #{EditorService::MIN_PASS} characters. Return alone: back.", GR)
        @screen.puts
        old = @screen.ask(" #{WH}current#{LG}> ", mask: '*', max: 200)
        return if old.empty?

        fresh = @screen.ask(" #{WH}new#{LG}> ", mask: '*', max: 200)
        again = @screen.ask(" #{WH}again#{LG}> ", mask: '*', max: 200)
        @screen.puts
        changed(fresh == again ? @editors.change_password(user.name, old, fresh) : :differ)
        @screen.pause
      end

      def changed(result)
        case result
        when :ok then @screen.say('Password changed.', GN)
        when :differ then @screen.say('The two new ones differ.', RD)
        else @screen.say(PASSWORD_ERRORS.fetch(result, 'The password could not be changed.'), RD)
        end
      end

      # The key the failed tries of this caller are counted by.
      def caller_key = @caller_key ||= BBS::RateLimit.caller_key(@screen.session)
    end
  end
end
