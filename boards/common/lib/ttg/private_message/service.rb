# frozen_string_literal: true

module TTG
  module PrivateMessage
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
  end
end
