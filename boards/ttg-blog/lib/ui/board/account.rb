# frozen_string_literal: true

module UI
  class Board < BBS::Petscii::Face
    # The editor's account on a call: logging in with the Teletype Games
    # account (BBS::Auth, kept on TTG Gate BBS; the blogger role makes an
    # editor) and changing its password. The limits on tries are the
    # gate's, counted by the name and by the caller.
    module Account
      PASSWORD_WORDING = Hash.new('The password could not be changed. Try again later.').merge(
        ok:        'Password changed.',
        differ:    'The two new ones differ.',
        wrong:     'The current password is wrong.',
        locked:    'Too many wrong passwords. Try again later.',
        too_short: "The new password needs at least #{BBS::Auth::Directory::MIN_PASSWORD} characters.",
        busy:      'The board is busy. Try again in a moment.'
      ).freeze

      private

      def editor_login
        title('LOG IN', right)
        say('Your Teletype Games account: the same on every board. Return alone: back.', color: GR)
        found = log_in or return
        alert("#{found.name} is not an editor of the blog.") unless found.role?(:blogger)
      end

      def secret(label) = prompt(label, mask: '*', max: 200)

      def password
        title('CHANGE PASSWORD', right)
        say("At least #{BBS::Auth::Directory::MIN_PASSWORD} characters. Return alone: back.", color: GR)
        old = secret('current')
        return unless old

        fresh = secret('new').to_s
        again = secret('again').to_s
        report(fresh == again ? change_password(old, fresh) : :differ, PASSWORD_WORDING)
      end

      def change_password(old, fresh)
        auth_setup.directory.change_password(identity.name, old, fresh, caller_key: caller_key)
      end
    end
  end
end
