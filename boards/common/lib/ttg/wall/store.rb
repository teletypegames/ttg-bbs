# frozen_string_literal: true

require 'time'

module TTG
  module Wall
    # The walls of the network on the Central (TTG Gate BBS): one a board,
    # where callers write and answer each other. Its answers are the Symbols
    # and Hashes of a Rubbs::Common::Central::Service op.
    #
    # An account writes once in ACCOUNT_GAP seconds and ACCOUNT_HOURLY an hour
    # on the network; a guest — always with a name — once in GUEST_GAP
    # seconds and GUEST_DAILY a day from one line, all guests GUESTS_HOURLY
    # an hour. A sysop hides a note (it stays, unseen) and can bar a guest's
    # line from the walls for a while.
    class Store
      # Seconds between an account's notes.
      ACCOUNT_GAP = 30
      # An account's notes in an hour.
      ACCOUNT_HOURLY = 30
      # Seconds between a guest line's notes.
      GUEST_GAP = 120
      # A guest line's notes in a day.
      GUEST_DAILY = 10
      # All guests' notes in an hour.
      GUESTS_HOURLY = 60
      # The longest note.
      MAX = 500
      # Days a caller_key is kept.
      KEEP_DAYS = 90

      # A store in the Sequel::Database +db+ (MIGRATIONS applied).
      def initialize(db)
        @db = db
      end

      # A note of +actor+ (a Rubbs::Common::Central::Actor) on the wall of
      # +board+, answering note +reply_to+ when given: +{ id: }+, or +:empty+,
      # +:name_needed+ (a guest without a name), +:barred+, +:too_soon+,
      # +:limited+, +:unknown_note+ (the note answered is not on this wall).
      def post(actor, board:, text:, reply_to: nil)
        text = Rubbs::Common::Text.line(text)[0, MAX]
        return :empty if text.empty?
        return :name_needed if actor.guest? && actor.name.to_s.empty?
        return :barred if actor.guest? && barred?(actor.caller_key)
        return :unknown_note if reply_to && visible.where(id: reply_to.to_i, board: board.to_s).none?

        problem = limit(actor) and return problem
        id = @db[:wall].insert(row(actor, board, text, reply_to))
        forget_old_keys
        { id: id }
      end

      # The newest +limit+ visible notes of +board+ (all boards when +nil+)
      # before the id +before+, oldest first: +{ notes: }+.
      def recent(board: nil, before: nil, limit: 20)
        rows = scope(board).reverse(:id).limit(limit.to_i.clamp(1, 100))
        rows = rows.where(Sequel[:id] < before.to_i) if before
        { notes: present(rows.all.reverse) }
      end

      # The visible notes of +board+ after the id +after+, oldest first.
      def since(board: nil, after: 0) = { notes: present(scope(board).where(Sequel[:id] > after.to_i).order(:id).limit(100).all) }

      # The note +id+ taken back by its writer (+actor+'s account, or a
      # guest's same line): +:ok+ or +:unknown_note+.
      def withdraw(actor, id)
        own = actor.account? ? { account_id: actor.id } : { account_id: nil, caller_key: actor.caller_key.to_s }
        if @db[:wall].where(id: id.to_i, hidden_at: nil, **own).update(
          hidden_at: now,
          hidden_by: actor.name.to_s,
          reason:    'withdrawn'
        )
            .positive?
          :ok
        else
          :unknown_note
        end
      end

      # Hides note +id+ (+by+ a sysop, for +reason+): +:ok+ or +:unknown_note+.
      def hide(id, by:, reason: nil)
        if @db[:wall].where(id: id.to_i).update(hidden_at: now, hidden_by: by.to_s, reason: reason.to_s[0, 200]).positive?
          :ok
        else
          :unknown_note
        end
      end

      # Shows note +id+ again: +:ok+ or +:unknown_note+.
      def unhide(id)
        @db[:wall].where(id: id.to_i).update(hidden_at: nil, hidden_by: nil, reason: nil).positive? ? :ok : :unknown_note
      end

      # Bars the line of note +id+'s guest from the walls for +hours+:
      # +:ok+, or +:unknown_note+ (or not a guest's).
      def bar(id, hours:, by:)
        key = @db[:wall].where(id: id.to_i, account_id: nil).get(:caller_key) or return :unknown_note
        until_at = (Time.now.utc + (hours.to_f * 3600)).iso8601
        @db[:wall_bars].insert_conflict(:replace).insert(caller_key: key, until_at: until_at, by: by.to_s)
        :ok
      end

      # Every note for the sysop, hidden ones too, newest first: +{ notes: }+.
      def moderation(before: nil, limit: 30)
        rows = @db[:wall].reverse(:id).limit(limit.to_i.clamp(1, 100))
        rows = rows.where(Sequel[:id] < before.to_i) if before
        { notes: present(rows.all, hidden: true) }
      end

      # Brings in notes from before the wall (a board's oneliners, posts):
      # rows of +board+, +name+, +text+, +created_at+, optionally
      # +account_id+. The length is kept. Returns the count.
      def import(rows)
        rows.each do |row|
          row = row.transform_keys(&:to_sym)
          @db[:wall].insert(
            created_at: row[:created_at].to_s.empty? ? now : row[:created_at].to_s,
            board:      row[:board].to_s,
            account_id: row[:account_id],
            name:       Rubbs::Common::Text.line(row[:name])[0, 40],
            guest:      row[:account_id] ? 0 : 1,
            text:       Rubbs::Common::Text.clean(row[:text]).strip,
            sysop:      0
          )
        end
        rows.size
      end

      private

      def visible = @db[:wall].where(hidden_at: nil)

      def scope(board) = board.to_s.empty? ? visible : visible.where(board: board.to_s)

      def present(rows, hidden: false)
        names = @db[:wall].where(id: rows.filter_map { |r| r[:reply_to] }).to_h { |r| [r[:id], r[:name]] }
        rows.map do |r|
          note = r.slice(:id, :created_at, :board, :name, :text, :reply_to, :face)
          note.merge(
            guest:      r[:guest] == 1,
            sysop:      r[:sysop] == 1,
            reply_name: names[r[:reply_to]],
            **(hidden ? r.slice(:hidden_at, :hidden_by, :reason, :account_id) : {})
          )
        end
      end

      def row(actor, board, text, reply_to)
        {
          created_at: now,
          board:      board.to_s,
          account_id: actor.id,
          name:       actor.name.to_s,
          guest:      actor.guest? ? 1 : 0,
          text:       text,
          reply_to:   reply_to&.to_i,
          face:       actor.face,
          caller_key: actor.caller_key,
          sysop:      actor.role?(:sysop) ? 1 : 0
        }
      end

      def limit(actor)
        mine = own(actor)
        gap, count, window = actor.account? ? [ACCOUNT_GAP, ACCOUNT_HOURLY, 3600] : [GUEST_GAP, GUEST_DAILY, 86_400]
        return :too_soon if mine.where(Sequel[:created_at] > ago(gap)).any?
        return :limited if mine.where(Sequel[:created_at] > ago(window)).count >= count

        :limited if actor.guest? && guests_this_hour >= GUESTS_HOURLY
      end

      def own(actor)
        if actor.account?
          @db[:wall].where(account_id: actor.id)
        else
          @db[:wall].where(account_id: nil, caller_key: actor.caller_key.to_s)
        end
      end

      def guests_this_hour = @db[:wall].where(account_id: nil).where(Sequel[:created_at] > ago(3600)).count

      def barred?(key) = @db[:wall_bars].where(caller_key: key.to_s).where(Sequel[:until_at] > now).any?

      def ago(seconds) = (Time.now.utc - seconds).iso8601

      def forget_old_keys
        @db[:wall].where(Sequel[:created_at] < ago(KEEP_DAYS * 86_400)).exclude(caller_key: nil).update(caller_key: nil)
      end

      def now = Time.now.utc.iso8601
    end
  end
end
