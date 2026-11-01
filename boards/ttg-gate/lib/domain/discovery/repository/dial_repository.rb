# frozen_string_literal: true

module Discovery
  # The Gate's dial records besides the probes: each refused dial (when, why,
  # which board, which face; nothing of the caller) and each dial's time on
  # the line and the bytes relayed. Both are kept for KEEP; the refusals that
  # go are added to their running totals in meta, so the totals only grow.
  class DialRepository
    KEEP = 30 * 86_400
    # The refused dials' reasons (DialService::Refusal) and the faces.
    REASONS = %w[rate busy not_petscii unknown].freeze
    FACES   = %w[modern c64].freeze
    PRUNE_EVERY = 3600
    PRUNED = 'dial_refusals_pruned'

    def initialize(db)
      @db = db
      @pruned_at = 0
    end

    # A refused dial of board +board_id+ (nil for no such board) on +face+.
    def refused(at:, reason:, board_id:, face:)
      @db.insert('INSERT INTO dial_refusals (at, reason, board_id, face) VALUES (?, ?, ?, ?)',
                 at.to_i, reason.to_s, board_id, face.to_s)
      prune(at.to_i)
    end

    # A dial that went: its +result+ (a probe result), the +seconds+ it was
    # connected and the +bytes+ the board sent through the Gate.
    def dialled(at:, board_id:, face:, result:, seconds:, bytes:)
      @db.insert('INSERT INTO dials (at, board_id, face, result, seconds, bytes) VALUES (?, ?, ?, ?, ?, ?)',
                 at.to_i, board_id, face.to_s, result.to_s, seconds.to_i, bytes.to_i)
      prune(at.to_i)
    end

    # Drops the records older than KEEP at +now+ (at most once in
    # PRUNE_EVERY unless +force+), the refusals' counts into their totals.
    def prune(now, force: false)
      return unless force || now - @pruned_at >= PRUNE_EVERY

      @pruned_at = now
      before = now - KEEP
      @db.transaction do
        @db.query('SELECT reason, face, COUNT(*) AS n FROM dial_refusals WHERE at < ? GROUP BY 1, 2', before).each do |r|
          @db.change(<<~SQL, "#{PRUNED}:#{r['reason']}:#{r['face']}", r['n'].to_s)
            INSERT INTO meta (key, value) VALUES (?, ?)
            ON CONFLICT (key) DO UPDATE SET value = CAST(value AS INTEGER) + CAST(excluded.value AS INTEGER)
          SQL
        end
        @db.change('DELETE FROM dial_refusals WHERE at < ?', before)
        @db.change('DELETE FROM dials WHERE at < ?', before)
      end
    end

    # Every refused dial ever, { [reason, face] => n }, every pair there.
    def refusal_totals
      totals = REASONS.product(FACES).to_h { |pair| [pair, 0] }
      @db.query('SELECT reason, face, COUNT(*) AS n FROM dial_refusals GROUP BY 1, 2').each do |r|
        totals[[r['reason'], r['face']]] = totals.fetch([r['reason'], r['face']], 0) + r['n']
      end
      @db.query('SELECT key, value FROM meta WHERE key LIKE ?', "#{PRUNED}:%").each do |r|
        _, reason, face = r['key'].split(':')
        totals[[reason, face]] = totals.fetch([reason, face], 0) + r['value'].to_i
      end
      totals
    end

    # The refused dials since +from+ a reason, every reason there.
    def refusals_since(from)
      counts = @db.query('SELECT reason, COUNT(*) AS n FROM dial_refusals WHERE at >= ? GROUP BY 1', from)
                  .to_h { |r| [r['reason'], r['n']] }
      REASONS.to_h { |r| [r, counts.fetch(r, 0)] }.merge(counts)
    end

    # The dials since +from+: how many, their seconds on the line and the
    # bytes relayed, summed.
    def traffic_since(from)
      row = @db.first('SELECT COUNT(*) AS n, COALESCE(SUM(seconds), 0) AS s, COALESCE(SUM(bytes), 0) AS b ' \
                      'FROM dials WHERE at >= ?', from)
      [row['n'].to_i, row['s'].to_i, row['b'].to_i]
    end
  end
end
