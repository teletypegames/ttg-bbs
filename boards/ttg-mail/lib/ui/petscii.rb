# frozen_string_literal: true

require_relative 'logo'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen, a cursor menu, the mailbox
  # (ttg-common TTG::PrivateMessage), the wall and a word to the sysops, and the caller's
  # profile to log in.
  class Petscii < Rubbs::Petscii::Face
    LOGO_COLORS = [LB, LB, CY, CY, WH].freeze

    title('TTG MAIL BBS') { signed_in? ? identity.name.to_s.downcase : 'guest' }

    masthead do
      gap
      art Logo.petscii(LOGO_COLORS)
      gap
      line 'letters between the accounts', color: WH, indent: 2
    end

    main_menu do
      item('m', 'mailbox', -> { mailbox_note }) { TTG::PrivateMessage.open(session) }
      item('w', 'the wall', 'talk with the other callers') { TTG::Wall.open(session) }
      item('f', 'write to the sysops', 'a bug, an idea, a word') { TTG::Feedback.open(session) }
      item('p', 'profile', -> { signed_in? ? identity.name : 'log in: mail is for accounts' }) { open_profile }
      log_off
    end

    private

    def mailbox_note
      return 'log in first (p)' unless signed_in?

      box = mail.summary(Rubbs::Common::Central::Actor.of(session))
      box.reachable ? "#{box.unread} new letters" : 'cannot be reached now'
    end
  end
end
