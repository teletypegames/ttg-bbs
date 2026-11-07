# frozen_string_literal: true

module TTG
  module Badges
    # The badges on the Central (TTG Gate BBS): rubbs'
    # Rubbs::Common::Badges::Service, and once at its start what came before
    # it: the Pioneer badge for the accounts made before LAUNCH, and the
    # notes, feedback and letters of the network as events, so the callers
    # of before have their Graffiti, Suggestion Box and Pen Pal.
    class Service < Rubbs::Common::Badges::Service
      # The service on the Central's +context+; fills in what came before.
      def initialize(context, **)
        super
        seed
      rescue StandardError => e
        Rubbs.log('badges seed', e)
      end

      private

      def seed
        pioneers
        past(:wall, :wall, :wall_note, :account_id)
        past(:feedback, :feedback, :feedback, :account_id)
        past(:messages, :messages, :letter, :from_account_id)
      end

      def pioneers
        badge = @catalog['pioneer'] or return
        return unless context.accounts

        before = LAUNCH.iso8601
        Rubbs::Common::Auth::AccountModel.where { created_at < before }.select_map(%i[id name]).each do |id, name|
          engine.grant(id, name, badge, board: 'network')
        end
      end

      def past(db, table, event, column)
        rows = context.databases[db]&.[](table) or return
        return if database[:badge_events].where(name: event.to_s).any?

        rows.exclude(column => nil).each do |row|
          at = Time.parse(row[:created_at].to_s)
          fact = Rubbs::Common::Badges::Fact.make(name: event, board: row[:board].to_s.delete_suffix('-bbs'), at: at)
          engine.record(row[column], row[:name] || row[:from_name], fact)
        end
      end
    end
  end
end
