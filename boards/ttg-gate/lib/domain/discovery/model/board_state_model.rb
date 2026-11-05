# frozen_string_literal: true

module Discovery
  # What the calls of a board add up to (StateRules, BannerAnalyzer, the
  # country), the row the Gate reads: its state and next call, where it
  # answered, its last banners and what the C64-style call found.
  class BoardStateModel < Rubbs::Common::Storage::Model
    table :board_state, database: :discovery

    # The states of a board.
    STATES = %w[online flaky down dead unknown].freeze
    # The boards a list of the Gate counts: no alias, not hidden.
    LISTED = "b.alias_of IS NULL AND (b.optout IS NULL OR b.optout != 'hide')"

    # The row of board +board_id+ as a Hash, or nil.
    def self.of(board_id) = where(board_id: board_id).naked.first

    # Writes +columns+ of the row of board +board_id+ (made when missing). A
    # binary String goes in as a BLOB.
    def self.save(board_id, **columns)
      dataset.insert_conflict(target: :board_id).insert(board_id: board_id)
      return if columns.empty?

      where(board_id: board_id).update(columns.transform_values { |v| blob?(v) ? Sequel.blob(v) : v })
    end

    # Whether +value+ is binary text (a banner).
    def self.blob?(value) = value.is_a?(String) && value.encoding == Encoding::BINARY

    # The boards due a probe at +now+: not aliases (unless +aliases+), not
    # hidden, not archived, their next probe time passed or never set; the
    # longest-waiting first. id, host, port, alias_of, ip, state, c64_only
    # and due_at.
    #
    # c64_only is 1 for a board that only wants a C64-style call now: an
    # answering board that a source calls a PETSCII board, or whose banner is
    # PETSCII, and that had no such call yet, or one with a shorter reading
    # window than +window+ (TelnetProbe::C64_TOTAL) that found no PETSCII.
    # Later the call follows the scheduled one, once a round.
    def self.due(now, limit:, window: TelnetProbe::C64_TOTAL)
      db.fetch(<<~SQL, now, window, TagModel::CLAIMS_PETSCII, now, limit).all
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

    # The boards a state, the archived ones apart: { 'online' => n, … }
    # (aliases and hidden boards are not counted).
    def self.counts
      db.fetch(<<~SQL).as_hash(:state, :n)
        SELECT CASE WHEN COALESCE(s.archived, 0) = 1 THEN 'archived' ELSE COALESCE(s.state, 'unknown') END AS state,
               COUNT(*) AS n
        FROM boards b LEFT JOIN board_state s ON s.board_id = b.id
        WHERE #{LISTED}
        GROUP BY 1
      SQL
    end

    # The boards the prober may call (not hidden, not archived): how many are
    # due at +now+, the earliest next probe time (nil without one), and since
    # when the longest-waiting due board has been due (+oldest_due_at+, nil
    # when none is; a board never probed is due since it was first seen).
    # A Hash of :due, :next_at and :oldest_due_at.
    def self.schedule(now)
      db.fetch(<<~SQL, now, now).first
        SELECT COUNT(*) FILTER (WHERE s.next_probe_at IS NULL OR s.next_probe_at <= ?) AS due,
               MIN(COALESCE(s.next_probe_at, 0)) AS next_at,
               MIN(COALESCE(s.next_probe_at, b.first_seen_at)) FILTER (WHERE s.next_probe_at IS NULL OR s.next_probe_at <= ?) AS oldest_due_at
        FROM boards b LEFT JOIN board_state s ON s.board_id = b.id
        WHERE (b.optout IS NULL OR b.optout != 'hide') AND COALESCE(s.archived, 0) = 0
      SQL
    end

    # The tags of the answering boards (online and flaky; aliases and hidden
    # ones apart): { tag => n }, and the number of those boards.
    def self.answering_tags
      boards = db.fetch(<<~SQL).single_value
        SELECT COUNT(*) FROM boards b JOIN board_state s ON s.board_id = b.id
        WHERE #{LISTED} AND s.state IN ('online', 'flaky')
      SQL
      tags = db.fetch(<<~SQL).as_hash(:tag, :n)
        SELECT t.tag, COUNT(*) AS n FROM tags t JOIN boards b ON b.id = t.board_id JOIN board_state s ON s.board_id = b.id
        WHERE #{LISTED} AND s.state IN ('online', 'flaky')
        GROUP BY t.tag
      SQL
      [tags, boards.to_i]
    end

    # The boards a state, the archived ones apart, the commonest first, for
    # bin/discovery-report (aliases apart, hidden ones in): [state, n] pairs.
    def self.report
      db.fetch(<<~SQL).map { |r| [r[:state], r[:n]] }
        SELECT CASE WHEN COALESCE(s.archived, 0) = 1 THEN 'archived' ELSE COALESCE(s.state, 'unknown') END AS state,
               COUNT(*) AS n
        FROM boards b LEFT JOIN board_state s ON s.board_id = b.id WHERE b.alias_of IS NULL GROUP BY 1 ORDER BY 2 DESC
      SQL
    end
  end
end
