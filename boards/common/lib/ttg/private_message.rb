# frozen_string_literal: true

require 'time'

module TTG
  # Letters from account to account, on any board: the network's mail, kept
  # on the Central (TTG Gate BBS) as a Rubbs::Common::Central::Service,
  # Service. No board offers it yet; the service and its rules are ready for
  # the board that does.
  #
  #   TTG::PrivateMessage.mail.call(:write, actor, to: 'Ada', subject: 'Hi', body: '…')
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

    # The letters on the Central: who may write to whom, how often, and the
    # boxes. Accounts only; a letter to an account that blocked the writer,
    # or to a banned one, is refused as if there were no such account.
    class Store
      # Seconds between two letters of an account.
      GAP = 30
      # An account's letters in a day.
      DAILY = 50
      # The longest subject and body.
      MAX = { subject: 60, body: 4000 }.freeze

      # A store in the Sequel::Database +db+, with +accounts+ (the Central's
      # Rubbs::Common::Auth::Directory) to find a recipient by name.
      def initialize(db, accounts)
        @db       = db
        @accounts = accounts
      end

      # A letter of +actor+ (an account) to +to+ (a name) from +board+:
      # +{ id: }+, or +:guest+, +:unknown_account+, +:empty+, +:too_soon+,
      # +:limited+.
      def write(actor, board:, to:, subject: '', body: '', reply_to: nil)
        return :guest if actor.guest?

        body = Rubbs::Common::Text.clean(body).strip[0, MAX[:body]]
        return :empty if body.empty?

        recipient = reachable(to, actor) or return :unknown_account
        problem = limit(actor) and return problem
        { id: @db[:messages].insert(letter(actor, board, recipient, subject, body, reply_to)) }
      end

      # The letters to +actor+, newest first: +{ letters: }+ (no body).
      def inbox(actor, before: nil, limit: 30) = box(:to_account_id, :deleted_by_recipient, actor, before, limit)

      # The letters of +actor+, newest first: +{ letters: }+ (no body).
      def outbox(actor, before: nil, limit: 30) = box(:from_account_id, :deleted_by_sender, actor, before, limit)

      # Letter +id+ of +actor+'s (to or from them), marked read when it is to
      # them: +{ letter: }+ or +:unknown+.
      def read(actor, id)
        row = mine(actor, id).first or return :unknown
        @db[:messages].where(id: row[:id]).update(read_at: now) if row[:to_account_id] == actor.id && row[:read_at].nil?
        { letter: row }
      end

      # Deletes letter +id+ from +actor+'s box: +:ok+ or +:unknown+.
      def delete(actor, id)
        row = mine(actor, id).first or return :unknown
        column = row[:to_account_id] == actor.id ? :deleted_by_recipient : :deleted_by_sender
        @db[:messages].where(id: row[:id]).update(column => 1)
        :ok
      end

      # The unread letters to +actor+: +{ count: }+.
      def unread(actor) = { count: @db[:messages].where(to_account_id: actor.id, read_at: nil, deleted_by_recipient: 0).count }

      # +actor+ takes no more letters from +name+ (+:ok+, +:unknown_account+),
      # or, with +on: false+, takes them again.
      def block(actor, name, on: true)
        other = @accounts&.find(name.to_s) or return :unknown_account
        rows = @db[:message_blocks]
        if on
          rows.insert_conflict.insert(account_id: actor.id, blocked_id: other.id)
        else
          rows.where(account_id: actor.id, blocked_id: other.id).delete
        end
        :ok
      end

      private

      def reachable(name, actor)
        found = @accounts&.find(name.to_s) or return nil
        return nil if @accounts.resolve(found.id) == :banned
        return nil if @db[:message_blocks].where(account_id: found.id, blocked_id: actor.id).any?

        found
      end

      def letter(actor, board, recipient, subject, body, reply_to)
        {
          created_at:      now,
          board:           board.to_s,
          from_account_id: actor.id,
          from_name:       actor.name.to_s,
          to_account_id:   recipient.id,
          to_name:         recipient.name,
          subject:         Rubbs::Common::Text.line(subject)[0, MAX[:subject]],
          body:            body,
          reply_to:        reply_to&.to_i
        }
      end

      def limit(actor)
        mine = @db[:messages].where(from_account_id: actor.id)
        return :too_soon if mine.where(Sequel[:created_at] > ago(GAP)).any?

        mine.where(Sequel[:created_at] > ago(86_400)).count >= DAILY ? :limited : nil
      end

      def box(column, deleted, actor, before, limit)
        rows = @db[:messages].where(column => actor.id, deleted => 0).reverse(:id).limit(limit.to_i.clamp(1, 100))
        rows = rows.where(Sequel[:id] < before.to_i) if before
        { letters: rows.select(:id, :created_at, :board, :from_name, :to_name, :subject, :read_at, :reply_to).all }
      end

      def mine(actor, id)
        @db[:messages].where(id: id.to_i).where(
          Sequel.|({ to_account_id: actor.id, deleted_by_recipient: 0 }, { from_account_id: actor.id, deleted_by_sender: 0 })
        )
      end

      def ago(seconds) = (Time.now.utc - seconds).iso8601

      def now = Time.now.utc.iso8601
    end

    # The letters as a service of the Central, on <tt>/messages</tt>, for
    # accounts only. Ops: +write+ (+to+, +subject+, +body+, +reply_to+),
    # +inbox+ and +outbox+ (+before+, +limit+), +read+ and +delete+ (+id+),
    # +unread+, +block+ and +unblock+ (+name+).
    class Service < Rubbs::Common::Central::Service
      path     '/messages'
      database :messages, MIGRATIONS

      op(:write) do |actor, to: '', subject: '', body: '', reply_to: nil, **|
        store.write(actor, board: asker, to: to, subject: subject, body: body, reply_to: reply_to)
      end
      op(:inbox) { |actor, before: nil, limit: 30, **| account(actor) { store.inbox(actor, before: before, limit: limit) } }
      op(:outbox) { |actor, before: nil, limit: 30, **| account(actor) { store.outbox(actor, before: before, limit: limit) } }
      op(:read) { |actor, id:, **| account(actor) { store.read(actor, id) } }
      op(:delete) { |actor, id:, **| account(actor) { store.delete(actor, id) } }
      op(:unread) { |actor, **| account(actor) { store.unread(actor) } }
      op(:block) { |actor, name:, **| account(actor) { store.block(actor, name) } }
      op(:unblock) { |actor, name:, **| account(actor) { store.block(actor, name, on: false) } }

      # A service on the Central's +context+.
      def initialize(context)
        super
        @store = Store.new(database, context.accounts)
      end

      # The Store.
      attr_reader :store

      private

      def account(actor) = actor.guest? ? :guest : yield
    end

    # The letters of the network on this board (a
    # Rubbs::Common::Central::Proxy of Service).
    def self.mail = Rubbs.central(Service)
  end
end
