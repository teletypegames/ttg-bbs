# frozen_string_literal: true

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen. The masthead is TTG MAIL in reversed
  # blocks (rubbs' BlockFont) over the line of the pillar box (the flag is up when the caller has new
  # letters), then a cursor menu: the mailbox (ttg-common TTG::PrivateMessage), the wall, a word to
  # the sysops, the profile.
  class Petscii < Rubbs::Petscii::Face
    # The colours of the five rows of the TTG MAIL lettering, the red of the pillar box going to white.
    LOGO_COLORS = [RD, RD, OR, YE, WH].freeze

    title('TTG MAIL BBS') { signed_in? ? identity.name.to_s.downcase : 'guest' }

    masthead do
      gap
      logo 'TTG MAIL', colors: LOGO_COLORS, indent: 5
      gap
      line 'letters between the accounts', color: LG, indent: 6
      line(color: YE, indent: 2) { pillar_box }
    end

    main_menu do
      item('m', 'mailbox', -> { mailbox_note }) { TTG::PrivateMessage.open(session) }
      item('w', 'the wall', 'talk with the other callers') { TTG::Wall.open(session) }
      item('f', 'write to the sysops', 'a bug, an idea, a word') { TTG::Feedback.open(session) }
      item('p', 'profile', -> { signed_in? ? identity.name : 'log in: mail is for accounts' }) { open_profile }
      log_off
    end

    private

    def box = mail.desk(Rubbs::Common::Central::Actor.of(session)).summary

    def pillar_box
      return "#{LG}the post office is closed for now" unless box.reachable
      return "#{LG}log in (p) to open your box" unless signed_in?
      return "#{GN}no new letters, #{identity.name.downcase}" unless box.unread.positive?

      "#{RD}▐#{YE}▀ flag up! #{WH}#{box.unread} new letter#{'s' unless box.unread == 1}"
    end

    def mailbox_note
      return 'log in first (p)' unless signed_in?

      box.reachable ? "#{box.unread} new letters" : 'cannot be reached now'
    end
  end
end
