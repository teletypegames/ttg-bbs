# frozen_string_literal: true

require_relative 'modern/helpers'
require_relative 'modern/post_office'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): the post office from the street
  # on the desktop (UI::Modern::PostOffice: the clock, the caller's name over the door, the pillar
  # box's flag for new letters, a pigeon in the sky), the newest letters and the newest notes of the
  # wall under it, and the mailbox (ttg-common TTG::PrivateMessage), the wall and a word to the
  # sysops each on the whole line.
  module Modern
    ABOUT = 'TTG Mail BBS — letters between the accounts of the Teletype Games BBS network, powered by rubbs. ' \
            'Log in with your account (You › Profile), then open your Mailbox (F2): write to any account, ' \
            'read and answer your letters, block a writer. The flag of the pillar box goes up for new letters.'

    APP = Rubbs::Modern::Application.define do
      theme :synchronet
      helpers { include Helpers }

      command(:mailbox, '&Mailbox…', key: 'F2', hint: 'Mailbox') { mailbox }
      command(:wall, 'The &wall…', key: 'F3', hint: 'Wall') { wall }
      command(:feedback, 'Write to the &sysops…', key: 'F7', hint: 'Sysops') { feedback }
      menu 'Mail', :mailbox, :wall, :feedback, :separator, :log_off
      menu 'You', :profile
      help about: ABOUT

      status do
        next 'log in to read your mail' unless signed_in?

        box = desk.summary
        box.reachable ? "#{box.unread} new letters" : 'the mail cannot be reached now'
      end

      desktop do
        widget(height: 13, top: 0) { PostOffice.new(desk: -> { desk }, name: -> { caller_or_nil }) }
        (0..3).each do |row|
          line(top: 14 + row, align: :left, margin: 4, style: row.zero? ? :accent : :text) { post_row(row) }
          line(top: 14 + row, align: :right, margin: 4, style: row.zero? ? :accent : :text) { wall_row(row) }
        end
      end
    end
  end
end
