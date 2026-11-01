# frozen_string_literal: true

module Discovery
  # What the Gate reads of the catalog: the boards of a list, their tags, the
  # page of one board. Read only; aliases and hidden boards (opt-out) are
  # never in it.
  class DirectoryRepository
    COLUMNS = <<~SQL
      SELECT b.id, b.host, b.port, b.name, b.first_seen_at, b.optout,
             COALESCE(s.state, 'unknown') AS state, s.state_since, s.last_success_at, s.first_probe_at,
             COALESCE(s.software, b.software) AS software, s.country,
             (SELECT group_concat(t.tag, ' ') FROM tags t WHERE t.board_id = b.id) AS tags
      FROM boards b LEFT JOIN board_state s ON s.board_id = b.id
      WHERE b.alias_of IS NULL AND (b.optout IS NULL OR b.optout != 'hide')
    SQL

    def initialize(db)
      @db = db
    end

    # The ListingModels a ListingFilter lets through, unsorted. An FTS query
    # the index cannot read gives none.
    def listings(filter)
      sql  = +COLUMNS
      args = []
      sql << " AND COALESCE(s.state, 'unknown') != 'dead'" unless filter.dead
      if filter.state
        sql << " AND COALESCE(s.state, 'unknown') = ?"
        args << filter.state
      end
      sql << " AND b.id NOT IN (SELECT board_id FROM tags WHERE tag = '#{ListingFilter::MAILER}')" unless filter.mailers
      tags = filter.tags + (filter.petscii ? ['petscii'] : [])
      tags.uniq!
      if tags.any?
        sql << " AND b.id IN (SELECT board_id FROM tags WHERE tag IN (#{(['?'] * tags.size).join(', ')}) " \
               'GROUP BY board_id HAVING COUNT(*) = ?)'
        args.concat(tags) << tags.size
      end
      if filter.match
        sql << ' AND b.id IN (SELECT rowid FROM boards_fts WHERE boards_fts MATCH ?)'
        args << filter.match
      end
      @db.query(sql, *args).map { |row| ListingModel.from(row) }
    rescue SQLite3::SQLException => e
      raise unless filter.match && e.message.match?(/fts5|syntax|MATCH/i)

      []
    end

    # One board's ListingModel, nil when it is not shown.
    def listing(id)
      row = @db.first("#{COLUMNS} AND b.id = ?", id)
      row && ListingModel.from(row)
    end

    # The BoardPageModel of a board at +now+, nil when it is not shown.
    def page(id, now: Time.now.to_i)
      listing = listing(id)
      return unless listing

      sources = @db.query(<<~SQL, id)
        SELECT bs.source_id, bs.active, src.name, src.attribution
        FROM board_sources bs LEFT JOIN sources src ON src.id = bs.source_id
        WHERE bs.board_id = ? ORDER BY bs.active DESC, bs.source_id
      SQL
      probes = @db.query('SELECT at, kind, result FROM probes WHERE board_id = ? AND at >= ? ORDER BY at',
                         id, now - ((BoardPageModel::STRIP_DAYS + 1) * 86_400))
      BoardPageModel.new(listing: listing, board: @db.first('SELECT * FROM boards WHERE id = ?', id),
                         state: @db.first('SELECT * FROM board_state WHERE board_id = ?', id) || {},
                         sources: sources, probes: probes)
    end

    # Every tag a board has: the vocabulary of the search.
    def vocabulary = @db.query('SELECT DISTINCT tag FROM tags').map { |r| r['tag'] }

    # When the first import ran (the boards of it are not new), epoch seconds.
    def started_at = @db.value("SELECT value FROM meta WHERE key = 'started_at'").to_i

    # The sources, for the Sources screen: id, name, url, attribution, licence,
    # record_count, last_parse_at.
    def sources = @db.query('SELECT * FROM sources ORDER BY id')
  end
end
