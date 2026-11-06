# frozen_string_literal: true

require_relative 'logo'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): the logo on the desktop, the
  # mailbox (ttg-common TTG::PrivateMessage), the wall and a word to the sysops, each on the
  # whole screen, and the caller's profile to log in.
  module Modern
    ABOUT = 'TTG Mail BBS — letters between the accounts of the Teletype Games BBS network, powered by rubbs. ' \
            'Log in with your account (You › Profile), then open your Mailbox (F2): write to any account, ' \
            'read and answer your letters, block a writer.'

    APP = Rubbs::Modern::Application.define do
      theme :synchronet

      command(:mailbox, '&Mailbox…', key: 'F2', hint: 'Mailbox') { with_line { TTG::PrivateMessage.open(@session) } }
      command(:wall, 'The &wall…', key: 'F3', hint: 'Wall') { with_line { TTG::Wall.open(@session) } }
      command(:feedback, 'Write to the &sysops…', key: 'F7', hint: 'Sysops') { with_line { TTG::Feedback.open(@session) } }
      menu 'Mail', :mailbox, :wall, :feedback, :separator, :log_off
      menu 'You', :profile
      help about: ABOUT

      status do
        next 'log in to read your mail' unless signed_in?

        box = mail.summary(Rubbs::Common::Central::Actor.of(@session))
        box.reachable ? "#{box.unread} new letters" : 'the mail cannot be reached now'
      end

      desktop do
        art Logo.half_blocks, top: 1
        line 'Letters between the accounts of the network', top: 5
        line 'F2 your mailbox   F3 the wall   You › Profile to log in', bottom: 1
      end
    end
  end
end
