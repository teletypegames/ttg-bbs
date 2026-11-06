# frozen_string_literal: true

require 'time'

module TTG
  # Letters from account to account: the network's mail, kept on the Central
  # (TTG Gate BBS) as a Rubbs::Common::Central::Service, Service, and read on
  # TTG Mail BBS with the Mailbox screen on either face. Accounts only.
  #
  #   TTG::PrivateMessage.open(session)                     # the mailbox, on either face
  #   TTG::PrivateMessage.unread(session)                   # letters not read yet (0 for a guest)
  #   TTG::PrivateMessage.mail.call(:write, actor, to: 'Ada', subject: 'Hi', body: '…')
  #
  # What the mailbox says comes from DEFAULTS and the board's own
  # (TTG::Narrative): a Hash, or <tt>lib/content/mail.yml</tt>.
  module PrivateMessage
    # The tables of the letters on the Central.
    MIGRATIONS = [
      <<~SQL
        CREATE TABLE messages (
          id                   INTEGER PRIMARY KEY,
          created_at           TEXT NOT NULL,
          board                TEXT NOT NULL,
          from_account_id      INTEGER NOT NULL,
          from_name            TEXT NOT NULL,
          to_account_id        INTEGER NOT NULL,
          to_name              TEXT NOT NULL,
          subject              TEXT NOT NULL DEFAULT '',
          body                 TEXT NOT NULL,
          reply_to             INTEGER,
          read_at              TEXT,
          deleted_by_sender    INTEGER NOT NULL DEFAULT 0,
          deleted_by_recipient INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX messages_to ON messages (to_account_id, id);
        CREATE INDEX messages_from ON messages (from_account_id, id);
        CREATE TABLE message_blocks (
          account_id INTEGER NOT NULL,
          blocked_id INTEGER NOT NULL,
          PRIMARY KEY (account_id, blocked_id)
        );
      SQL
    ].freeze

    # What the mailbox says when the board says nothing (TTG::Narrative).
    DEFAULTS = {
      title:       'Mailbox',
      intro:       'Letters between the accounts of the network: write to anyone with an account.',
      sent_title:  'Sent letters',
      empty:       'No letters here.',
      write:       'Write a letter',
      sent:        'Sent letters',
      inbox:       'Back to the inbox',
      back:        'Back',
      reply:       'Reply',
      delete:      'Delete',
      block:       'Block the sender',
      to:          { label: 'To (an account name)' },
      subject:     { label: 'Subject', max: 60 },
      body:        { label: 'Your letter', max: 4000 },
      unread_mark: 'new',
      thanks:      'Sent.',
      deleted:     'Deleted.',
      blocked:     'You take no more letters from %<name>s.',
      guest:       'Mail is for the accounts of the network: log in or make an account (your profile).',
      empty_body:  'Nothing to send.',
      unknown:     'There is no account by that name (or it takes no letters from you).',
      too_soon:    'Not so fast: wait a little before the next letter.',
      limited:     'That is all the letters for today.',
      unavailable: 'The mail cannot be reached now. Please try again later.',
      petscii:     { intro: 'LETTERS BETWEEN THE ACCOUNTS OF THE NETWORK.' }
    }.freeze

    # The letters of the network on this board (a
    # Rubbs::Common::Central::Proxy of Service).
    def self.mail = Rubbs.central(Service)

    # Shows the mailbox (Mailbox) to the caller on +session+; +narrative+ a
    # TTG::Narrative, a Hash or a path (default: the board's
    # <tt>lib/content/mail.yml</tt>). Returns +nil+.
    def self.open(session, narrative: nil) = Mailbox.new(session, narrative_of(narrative)).run

    # How many letters to the caller on +session+ are not read yet: 0 for a
    # guest, and when the Central does not answer.
    def self.unread(session)
      return 0 unless session.identity.signed_in?

      mail.call(:unread, Rubbs::Common::Central::Actor.of(session))['count'].to_i
    end

    # +given+ as a TTG::Narrative on DEFAULTS.
    def self.narrative_of(given)
      return given if given.is_a?(Narrative)

      Narrative.new(DEFAULTS, given || File.expand_path('lib/content/mail.yml', Dir.pwd))
    end
  end
end

require_relative 'private_message/store'
require_relative 'private_message/service'
require_relative 'private_message/mailbox'
