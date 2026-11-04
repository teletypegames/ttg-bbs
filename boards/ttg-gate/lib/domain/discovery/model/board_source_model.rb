# frozen_string_literal: true

require 'json'

module Discovery
  # A board as one source lists it: the fields of its record (JSON), and
  # whether the source's last import still had it (+active+).
  class BoardSourceModel < BBS::Model
    table :board_sources, database: :discovery

    # The rows of board +board_id+ as Hashes, +fields+ parsed (String keys).
    def self.of(board_id)
      where(board_id: board_id).naked.all.map { |row| row.merge(fields: JSON.parse(row[:fields])) }
    end

    # Makes +records+ (RecordModels) the active records of +source_id+: every
    # endpoint gets a board (a new one when its host:port is new), the
    # record's fields go into its row, and the source's other rows turn
    # inactive. One transaction.
    def self.apply(source_id, records, now)
      db.transaction do
        where(source_id: source_id).update(active: 0)
        records.each do |record|
          id = BoardModel.id_for(record.host, record.port, now)
          upsert(id, source_id, JSON.generate(record.stored_fields), now)
          BoardModel.seen(id, now)
        end
      end
    end

    # Writes the row of board +board_id+ in +source_id+: made active with
    # +fields+ (JSON), first seen at +now+ when new.
    def self.upsert(board_id, source_id, fields, now)
      dataset.insert_conflict(target: %i[board_id source_id],
                              update: { fields: Sequel[:excluded][:fields], active: 1,
                                        last_seen_at: Sequel[:excluded][:last_seen_at] })
             .insert(board_id: board_id, source_id: source_id, fields: fields, active: 1, first_seen_at: now,
                     last_seen_at: now)
    end

    # Turns the rows of the sources not in +ids+ inactive (a source switched
    # off in the config).
    def self.deactivate_other_sources(ids)
      rows = ids.any? ? exclude(source_id: ids) : dataset
      rows.update(active: 0)
    end

    # The sources of board +board_id+ for its page, the active ones first:
    # source_id, active, and the source's name and attribution.
    def self.listed(board_id)
      db.fetch(<<~SQL, board_id).all
        SELECT bs.source_id, bs.active, src.name, src.attribution
        FROM board_sources bs LEFT JOIN sources src ON src.id = bs.source_id
        WHERE bs.board_id = ? ORDER BY bs.active DESC, bs.source_id
      SQL
    end

    # The boards two sources both list now: { [source_id, source_id] => n }
    # (a source with itself: the boards it lists).
    def self.overlap
      db.fetch(<<~SQL).to_hash(%i[a b], :n)
        SELECT a.source_id AS a, b.source_id AS b, COUNT(*) AS n
        FROM board_sources a JOIN board_sources b ON a.board_id = b.board_id
        WHERE a.active = 1 AND b.active = 1 GROUP BY 1, 2
      SQL
    end

    # The number of boards more than one source lists now.
    def self.shared
      db.fetch(<<~SQL).single_value
        SELECT COUNT(*) FROM (SELECT board_id FROM board_sources WHERE active = 1 GROUP BY board_id HAVING COUNT(*) > 1)
      SQL
    end
  end
end
