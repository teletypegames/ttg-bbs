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
    # The kind of a C64-style probe.
    C64 = 'c64'
    # The tag of a board a source says is a PETSCII board.
    CLAIMS_PETSCII = 'claims:petscii'

    def initialize(db)
      @db = db
    end

    def transaction(&) = @db.transaction(&)

    # Stores +probe+ (a ProbeResultModel) of a board. The banner is kept only
    # when its hash differs from the board's last one of the same kind of
    # call (a C64-style call has a banner of its own).
    def add(board_id, probe, kind:, banner_hash:)
      column = kind == C64 ? 'c64_banner_hash' : 'banner_hash'
      last = @db.value("SELECT #{column} FROM board_state WHERE board_id = ?", board_id)
      banner = probe.banner.empty? || banner_hash == last ? nil : SQLite3::Blob.new(probe.banner)
      args = [board_id, probe.at, kind, probe.result, probe.latency_ms, probe.ip, banner, banner_hash,
              JSON.generate(probe.options), probe.duration_ms, probe.banner.bytesize]
      @db.insert(<<~SQL, *args)
        INSERT INTO probes (board_id, at, kind, result, latency_ms, ip, banner, banner_hash, options, duration_ms,
                            banner_bytes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      SQL
    end

    # The probes of a board since +from+ (epoch seconds), oldest first: at,
    # kind and result. The C64-style calls are left out: the state is of the
    # scheduled calls and the dials, one a round.
    def since(board_id, from)
      @db.query('SELECT at, kind, result FROM probes WHERE board_id = ? AND at >= ? AND kind != ? ORDER BY at, id',
                board_id, from, C64)
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
    # longest-waiting first. id, host, port, ip, state and c64_only.
    #
    # c64_only is 1 for a board that only wants a C64-style call now: an
    # answering board that a source calls a PETSCII board, or whose banner is
    # PETSCII, and that had no such call yet, or one with a shorter reading
    # window than +window+ (TelnetProbe::C64_TOTAL) that found no PETSCII.
    # Later the call follows the scheduled one, once a round.
    def due(now, limit:, window: TelnetProbe::C64_TOTAL)
      @db.query(<<~SQL, now, window, CLAIMS_PETSCII, now, limit)
        SELECT * FROM (
          SELECT b.id, b.host, b.port, b.alias_of, s.ip, COALESCE(s.state, 'unknown') AS state, 0 AS c64_only,
                 COALESCE(s.next_probe_at, 0) AS due_at
          FROM boards b LEFT JOIN board_state s ON s.board_id = b.id
          WHERE (b.optout IS NULL OR b.optout != 'hide')
            AND COALESCE(s.archived, 0) = 0
            AND (s.next_probe_at IS NULL OR s.next_probe_at <= ?)
          UNION ALL
          SELECT b.id, b.host, b.port, b.alias_of, s.ip, s.state, 1, s.last_probe_at
          FROM boards b JOIN board_state s ON s.board_id = b.id
          WHERE (b.optout IS NULL OR b.optout != 'hide') AND b.alias_of IS NULL
            AND s.archived = 0 AND s.state IN ('online', 'flaky')
            AND (s.c64_probe_at IS NULL OR (COALESCE(s.c64_window, 0) < ? AND COALESCE(s.c64_encoding, '') != 'petscii'))
            AND (s.encoding = 'petscii' OR b.id IN (SELECT board_id FROM tags WHERE tag = ?))
            AND s.next_probe_at > ?
        )
        ORDER BY due_at, id
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

    # The boards the prober may call (not hidden, not archived): how many are
    # due at +now+, the earliest next probe time (nil without one), and since
    # when the longest-waiting due board has been due (+oldest_due_at+, nil
    # when none is; a board never probed is due since it was first seen).
    def schedule(now)
      @db.first(<<~SQL, now, now)
        SELECT COUNT(*) FILTER (WHERE s.next_probe_at IS NULL OR s.next_probe_at <= ?) AS due,
               MIN(COALESCE(s.next_probe_at, 0)) AS next_at,
               MIN(COALESCE(s.next_probe_at, b.first_seen_at)) FILTER (WHERE s.next_probe_at IS NULL OR s.next_probe_at <= ?) AS oldest_due_at
        FROM boards b LEFT JOIN board_state s ON s.board_id = b.id
        WHERE (b.optout IS NULL OR b.optout != 'hide') AND COALESCE(s.archived, 0) = 0
      SQL
    end

    # Every stored probe a result and kind: { [result, kind] => n }.
    def totals
      @db.query('SELECT result, kind, COUNT(*) AS n FROM probes GROUP BY result, kind')
         .to_h { |r| [[r['result'], r['kind']], r['n']] }
    end

    # The scheduled probes since +from+ a result: their average whole-call
    # time in ms ({ 'ok' => avg, … }), and the longest.
    def durations(from)
      rows = @db.query(<<~SQL, from)
        SELECT result, AVG(duration_ms) AS avg, MAX(duration_ms) AS max FROM probes
        WHERE at >= ? AND kind = 'scheduled' AND duration_ms IS NOT NULL GROUP BY result
      SQL
      [rows.to_h { |r| [r['result'], r['avg']] }, rows.map { |r| r['max'] }.max]
    end

    # The average banner of the scheduled probes since +from+ that read one,
    # in bytes (nil without one).
    def banner_bytes(from)
      @db.value("SELECT AVG(banner_bytes) FROM probes WHERE at >= ? AND kind = 'scheduled' AND banner_bytes > 0",
                from)
    end

    # The tags of the answering boards (online and flaky; aliases and hidden
    # ones apart) that start with +prefix+, or are in +tags+: { tag => n },
    # and the number of those boards.
    def answering_tags
      boards = @db.value(<<~SQL)
        SELECT COUNT(*) FROM boards b JOIN board_state s ON s.board_id = b.id
        WHERE b.alias_of IS NULL AND (b.optout IS NULL OR b.optout != 'hide') AND s.state IN ('online', 'flaky')
      SQL
      tags = @db.query(<<~SQL).to_h { |r| [r['tag'], r['n']] }
        SELECT t.tag, COUNT(*) AS n FROM tags t JOIN boards b ON b.id = t.board_id JOIN board_state s ON s.board_id = b.id
        WHERE b.alias_of IS NULL AND (b.optout IS NULL OR b.optout != 'hide') AND s.state IN ('online', 'flaky')
        GROUP BY t.tag
      SQL
      [tags, boards.to_i]
    end
  end
end
