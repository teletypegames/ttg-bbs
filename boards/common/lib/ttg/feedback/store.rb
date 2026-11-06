# frozen_string_literal: true

require 'time'

module TTG
  module Feedback
    # The feedback of the network on the Central (TTG Gate BBS): what callers
    # send the sysops from any board, and the sysops' handling of it. Its
    # answers are the Symbols and Hashes of a Rubbs::Common::Central::Service
    # op.
    #
    # Limits, on the Central for every board together: an account
    # ACCOUNT_HOURLY an hour; a guest's line GUEST_DAILY a day; all guests
    # GUESTS_HOURLY an hour. A guest's +caller_key+ is forgotten after
    # KEEP_DAYS.
    class Store
      # The most a signed-in caller sends in an hour.
      ACCOUNT_HOURLY = 10
      # The most a guest's line sends in a day.
      GUEST_DAILY = 3
      # The most all guests send in an hour.
      GUESTS_HOURLY = 60
      # Days a caller_key is kept.
      KEEP_DAYS = 90
      # The longest subject, body, link and context.
      MAX = { subject: 60, body: 2000, link: 300, context: 200, kind: 20 }.freeze
      # The states of a feedback, in order.
      STATES = %w[new read done spam].freeze

      # A store in the Sequel::Database +db+ (MIGRATIONS applied); +notify+ is
      # called with every new feedback (a Hash), for the Discord line.
      def initialize(db, notify: nil)
        @db     = db
        @notify = notify
      end

      # Files feedback from +actor+ (a Rubbs::Common::Central::Actor) sent on
      # +board+: +{ id: }+, or +:empty+, +:bad_link+, +:limited+.
      def add(actor, board:, subject: '', body: '', kind: 'feedback', link: nil, context: nil)
        body = Rubbs::Common::Text.clean(body).strip[0, MAX[:body]]
        return :empty if body.empty?

        link = clean_link(link)
        return :bad_link if link == :bad
        return :limited unless allowed?(actor)

        row = record(actor, board, kind: kind, subject: subject, body: body, link: link, context: context)
        id  = @db[:feedback].insert(row)
        forget_old_keys
        @notify&.call(row.merge(id: id))
        { id: id }
      end

      # The feedback, newest first: +limit+ of them before the id +before+,
      # only those in +state+ when given. A Hash of +items+.
      def list(state: nil, before: nil, limit: 30)
        rows = @db[:feedback].reverse(:id).limit(limit.to_i.clamp(1, 100))
        rows = rows.where(state: state.to_s) if state
        rows = rows.where(Sequel[:id] < before.to_i) if before
        { items: rows.all.map { |row| row.except(:caller_key) } }
      end

      # Feedback +id+, marked +read+ when it was +new+: +{ item: }+ or
      # +:unknown+.
      def read(id, by:)
        row = @db[:feedback].where(id: id.to_i).first or return :unknown
        mark(id, 'read', by: by) if row[:state] == 'new'
        { item: @db[:feedback].where(id: id.to_i).first.except(:caller_key) }
      end

      # Sets feedback +id+ to +state+ (one of STATES) with +note+: +:ok+,
      # +:unknown+ or +:bad_state+.
      def mark(id, state, by:, note: nil)
        return :bad_state unless STATES.include?(state.to_s)

        set = { state: state.to_s, handled_by: by.to_s, handled_at: now }
        set[:note] = Rubbs::Common::Text.line(note)[0, 300] if note
        @db[:feedback].where(id: id.to_i).update(set).positive? ? :ok : :unknown
      end

      # Deletes feedback +id+: +:ok+ or +:unknown+.
      def delete(id) = @db[:feedback].where(id: id.to_i).delete.positive? ? :ok : :unknown

      # The counts by state, a Hash of String => Integer.
      def counts = @db[:feedback].group_and_count(:state).to_h { |row| [row[:state], row[:count]] }

      # Brings in old feedback (a board's own box before the Central): rows
      # with +board+, +kind+, +name+, +subject+, +body+, +created_at+ and
      # optionally +state+, +link+, +context+. Returns the count brought in.
      def import(rows)
        rows.sum do |row|
          row = row.transform_keys(&:to_sym)
          @db[:feedback].insert(imported(row))
          1
        end
      end

      private

      def record(actor, board, kind:, subject:, body:, link:, context:)
        {
          created_at: now,
          board:      board.to_s,
          kind:       Rubbs::Common::Text.line(kind)[0, MAX[:kind]].then { |k|
            k.empty? ? 'feedback' : k
          },
          subject:    Rubbs::Common::Text.line(subject)[0, MAX[:subject]],
          body:       body,
          link:       link,
          context:    context && Rubbs::Common::Text.line(context)[0, MAX[:context]],
          account_id: actor.id,
          name:       actor.name,
          caller_key: actor.caller_key,
          face:       actor.face,
          state:      'new'
        }
      end

      def imported(row)
        {
          created_at: row[:created_at].to_s.empty? ? now : row[:created_at].to_s,
          board:      row[:board].to_s,
          kind:       row[:kind] || 'feedback',
          subject:    Rubbs::Common::Text.line(row[:subject])[0, MAX[:subject]],
          body:       Rubbs::Common::Text.clean(row[:body]).strip,
          link:       row[:link],
          context:    row[:context],
          name:       row[:name],
          state:      STATES.include?(row[:state].to_s) ? row[:state].to_s : 'read'
        }
      end

      def clean_link(link)
        link = Rubbs::Common::Text.line(link)
        return nil if link.empty?
        return :bad unless link.match?(%r{\Ahttps?://\S+\z}i) && link.length <= MAX[:link]

        link
      end

      def allowed?(actor)
        rows = @db[:feedback]
        return rows.where(account_id: actor.id).where(Sequel[:created_at] > ago(3600)).count < ACCOUNT_HOURLY if actor.account?

        rows.where(
          account_id: nil,
          caller_key: actor.caller_key.to_s
        ).where(Sequel[:created_at] > ago(86_400)).count < GUEST_DAILY &&
          rows.where(account_id: nil).where(Sequel[:created_at] > ago(3600)).count < GUESTS_HOURLY
      end

      def ago(seconds) = (Time.now.utc - seconds).iso8601

      def forget_old_keys
        @db[:feedback].where(Sequel[:created_at] < ago(KEEP_DAYS * 86_400)).exclude(caller_key: nil).update(caller_key: nil)
      end

      def now = Time.now.utc.iso8601
    end
  end
end
