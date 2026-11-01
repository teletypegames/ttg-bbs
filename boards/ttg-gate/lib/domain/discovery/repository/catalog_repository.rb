# frozen_string_literal: true

require 'json'

module Discovery
  # The catalog tables of Database: sources, boards, board_sources, tags and
  # the full-text index. The import and the tag rules work through it.
  class CatalogRepository
    def initialize(db)
      @db = db
    end

    def transaction(&) = @db.transaction(&)

    # -- sources -------------------------------------------------------------

    def source(id) = @db.first('SELECT * FROM sources WHERE id = ?', id)

    def sources = @db.query('SELECT * FROM sources ORDER BY id')

    # Writes the config of +source+ (a SourceModel) and +changes+ (columns).
    def save_source(source, **changes)
      @db.change(<<~SQL, source.id, source.name, source.url, source.format, source.licence, source.attribution)
        INSERT INTO sources (id, name, url, format, licence, attribution) VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT (id) DO UPDATE SET name = excluded.name, url = excluded.url, format = excluded.format,
          licence = excluded.licence, attribution = excluded.attribution
      SQL
      return if changes.empty?

      sets = changes.keys.map { |k| "#{k} = ?" }.join(', ')
      @db.change("UPDATE sources SET #{sets} WHERE id = ?", *changes.values, source.id)
    end

    # -- the records of a source ----------------------------------------------

    # Makes +records+ (RecordModels) the active records of +source_id+: every
    # endpoint gets a board (a new one when its host:port is new), the record's
    # fields go into board_sources, and the source's other rows turn inactive.
    # One transaction.
    def apply(source_id, records, now)
      transaction do
        @db.change('UPDATE board_sources SET active = 0 WHERE source_id = ?', source_id)
        records.each do |record|
          id = board_id(record.host, record.port, now)
          @db.change(<<~SQL, id, source_id, JSON.generate(record.stored_fields), now, now)
            INSERT INTO board_sources (board_id, source_id, fields, active, first_seen_at, last_seen_at)
            VALUES (?, ?, ?, 1, ?, ?)
            ON CONFLICT (board_id, source_id) DO UPDATE SET fields = excluded.fields, active = 1,
              last_seen_at = excluded.last_seen_at
          SQL
          @db.change('UPDATE boards SET last_seen_at = ? WHERE id = ?', now, id)
        end
      end
    end

    # Turns the rows of the sources not in +ids+ inactive (a source switched
    # off in the config).
    def deactivate_other_sources(ids)
      marks = (['?'] * ids.size).join(', ')
      sql = 'UPDATE board_sources SET active = 0'
      sql += " WHERE source_id NOT IN (#{marks})" if ids.any?
      @db.change(sql, *ids)
    end

    def board_id(host, port, now)
      id = @db.value('SELECT id FROM boards WHERE host = ? AND port = ?', host, port)
      id || @db.insert('INSERT INTO boards (host, port, first_seen_at, last_seen_at) VALUES (?, ?, ?, ?)',
                       host, port, now, now)
    end

    # -- boards ---------------------------------------------------------------

    def board(id) = @db.first('SELECT * FROM boards WHERE id = ?', id)

    def board_ids = @db.query('SELECT id FROM boards ORDER BY id').map { |r| r['id'] }

    # The board_sources rows of a board, fields parsed.
    def board_sources(board_id)
      @db.query('SELECT * FROM board_sources WHERE board_id = ?', board_id).map do |row|
        row.merge('fields' => JSON.parse(row['fields']))
      end
    end

    # Writes the resolved fields of a board, their provenance and its delisted
    # mark (+delisted_at+ is set when it turns delisted).
    def update_board(id, fields, provenance, delisted, now)
      cols = RecordModel::FIELDS.map { |f| "#{f} = ?" }.join(', ')
      flag = delisted ? 1 : 0
      args = RecordModel::FIELDS.map { |f| fields[f.to_s] } + [JSON.generate(provenance), flag, flag, now, id]
      @db.change(<<~SQL, *args)
        UPDATE boards SET #{cols}, provenance = ?, delisted = ?,
          delisted_at = CASE WHEN ? = 1 THEN COALESCE(delisted_at, ?) ELSE NULL END
        WHERE id = ?
      SQL
    end

    def set_optout(id, level) = @db.change('UPDATE boards SET optout = ? WHERE id = ?', level, id)

    def set_alias(id, canonical) = @db.change('UPDATE boards SET alias_of = ? WHERE id = ?', canonical, id)

    # The boards with a known address: id, host, port, alias_of, ip, optout and
    # the number of active sources.
    def addresses
      @db.query(<<~SQL)
        SELECT b.id, b.host, b.port, b.alias_of, b.optout, s.ip,
               (SELECT COUNT(*) FROM board_sources bs WHERE bs.board_id = b.id AND bs.active = 1) AS sources
        FROM boards b LEFT JOIN board_state s ON s.board_id = b.id
      SQL
    end

    # -- tags and search ------------------------------------------------------

    def tags(board_id) = @db.query('SELECT tag FROM tags WHERE board_id = ? ORDER BY tag', board_id).map { |r| r['tag'] }

    def replace_tags(board_id, tags)
      transaction do
        @db.change('DELETE FROM tags WHERE board_id = ?', board_id)
        tags.uniq.each { |t| @db.change('INSERT INTO tags (board_id, tag) VALUES (?, ?)', board_id, t) }
      end
    end

    # Writes a board's row of the full-text index: the name, sysop, location,
    # the software (the banner's when known, else the source's) and the host.
    def index(board_id)
      row = @db.first(<<~SQL, board_id)
        SELECT b.id, b.name, b.sysop, b.location, COALESCE(s.software, b.software) AS software, b.host
        FROM boards b LEFT JOIN board_state s ON s.board_id = b.id WHERE b.id = ?
      SQL
      return unless row

      transaction do
        @db.change('DELETE FROM boards_fts WHERE rowid = ?', board_id)
        @db.change('INSERT INTO boards_fts (rowid, name, sysop, location, software, host) VALUES (?, ?, ?, ?, ?, ?)',
                   board_id, row['name'], row['sysop'], row['location'], row['software'], row['host'])
      end
    end

    # The board ids whose index matches an FTS5 +query+.
    def search(query) = @db.query('SELECT rowid FROM boards_fts WHERE boards_fts MATCH ?', query).map { |r| r['rowid'] }

    # -- meta -----------------------------------------------------------------

    def meta(key) = @db.value('SELECT value FROM meta WHERE key = ?', key)

    def set_meta(key, value)
      @db.change('INSERT INTO meta (key, value) VALUES (?, ?) ON CONFLICT (key) DO UPDATE SET value = excluded.value',
                 key, value.to_s)
    end
  end
end
