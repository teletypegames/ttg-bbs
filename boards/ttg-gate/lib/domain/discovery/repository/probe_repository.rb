# frozen_string_literal: true

require 'json'

module Discovery
  # The probe tables of Database: probes (every call, kept) and board_state
  # (what they add up to, which the Gate reads).
  class ProbeRepository
    # A banner is kept with its probe this long; then only the newest one of a
    # board stays (in board_state), so the history keeps its hashes, not 4 KB
    # a day a board.
    BANNER_DAYS = 30

    def initialize(db)
      @db = db
    end

    def transaction(&) = @db.transaction(&)

    # Stores +probe+ (a ProbeResultModel) of a board. The banner is kept only
    # when its hash differs from the board's last one.
    def add(board_id, probe, kind:, banner_hash:)
      last = @db.value('SELECT banner_hash FROM board_state WHERE board_id = ?', board_id)
      banner = probe.banner.empty? || banner_hash == last ? nil : SQLite3::Blob.new(probe.banner)
      args = [board_id, probe.at, kind, probe.result, probe.latency_ms, probe.ip, banner, banner_hash,
              JSON.generate(probe.options)]
      @db.insert(<<~SQL, *args)
        INSERT INTO probes (board_id, at, kind, result, latency_ms, ip, banner, banner_hash, options)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      SQL
    end

    # The probes of a board since +from+ (epoch seconds), oldest first: at,
    # kind and result.
    def since(board_id, from)
      @db.query('SELECT at, kind, result FROM probes WHERE board_id = ? AND at >= ? ORDER BY at, id', board_id, from)
    end

    # The board_state row of a board, or nil.
    def state(board_id) = @db.first('SELECT * FROM board_state WHERE board_id = ?', board_id)

    # Writes +columns+ of a board's board_state row (made when missing).
    def save_state(board_id, **columns)
      @db.change('INSERT INTO board_state (board_id) VALUES (?) ON CONFLICT (board_id) DO NOTHING', board_id)
      return if columns.empty?

      values = columns.values.map { |v| v.is_a?(String) && v.encoding == Encoding::BINARY ? SQLite3::Blob.new(v) : v }
      @db.change("UPDATE board_state SET #{columns.keys.map { |k| "#{k} = ?" }.join(', ')} WHERE board_id = ?",
                 *values, board_id)
    end

    # The boards due a probe at +now+: not aliases (unless +aliases+), not
    # hidden, not archived, their next probe time passed or never set; the
    # longest-waiting first. id, host, port, ip and state.
    def due(now, limit:)
      @db.query(<<~SQL, now, limit)
        SELECT b.id, b.host, b.port, b.alias_of, s.ip, COALESCE(s.state, 'unknown') AS state
        FROM boards b LEFT JOIN board_state s ON s.board_id = b.id
        WHERE (b.optout IS NULL OR b.optout != 'hide')
          AND COALESCE(s.archived, 0) = 0
          AND (s.next_probe_at IS NULL OR s.next_probe_at <= ?)
        ORDER BY COALESCE(s.next_probe_at, 0), b.id
        LIMIT ?
      SQL
    end

    # Drops the banners of probes older than BANNER_DAYS (the hash stays).
    def prune_banners(now)
      @db.change('UPDATE probes SET banner = NULL WHERE banner IS NOT NULL AND at < ?', now - (BANNER_DAYS * 86_400))
    end

    # The boards a state, the archived ones apart: { 'online' => n, … }.
    def state_counts
      rows = @db.query(<<~SQL)
        SELECT CASE WHEN COALESCE(s.archived, 0) = 1 THEN 'archived' ELSE COALESCE(s.state, 'unknown') END AS state,
               COUNT(*) AS n
        FROM boards b LEFT JOIN board_state s ON s.board_id = b.id
        WHERE b.alias_of IS NULL AND (b.optout IS NULL OR b.optout != 'hide')
        GROUP BY 1
      SQL
      rows.to_h { |r| [r['state'], r['n']] }
    end

    # The probes (of +kind+, or of any) since +from+ a result: { 'ok' => n, … }.
    def result_counts(from, kind: nil)
      sql = 'SELECT result, COUNT(*) AS n FROM probes WHERE at >= ?'
      sql += ' AND kind = ?' if kind
      @db.query("#{sql} GROUP BY result", from, *kind).to_h { |r| [r['result'], r['n']] }
    end

    def last_probe_at = @db.value('SELECT MAX(at) FROM probes')
  end
end
