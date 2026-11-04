# frozen_string_literal: true

require 'json'

module Discovery
  # A telnet endpoint of the catalog, one a host:port: the fields its
  # sources gave (resolved by their priority), where each came from, and
  # whether it is delisted, hidden (opt-out) or an alias of another board.
  class BoardModel < BBS::Model
    table :boards, database: :discovery

    # The boards a Gate list may show: no alias, not hidden.
    SHOWN = "SELECT b.id FROM boards b WHERE b.alias_of IS NULL AND (b.optout IS NULL OR b.optout != 'hide')"

    # Every board id, in order.
    def self.ids = order(:id).select_map(:id)

    # The id of the board at +host+:+port+, the board made (first seen at
    # +now+) when there is none.
    def self.id_for(host, port, now)
      where(host: host, port: port).get(:id) ||
        insert(host: host, port: port, first_seen_at: now, last_seen_at: now)
    end

    # Marks board +id+ seen at +now+.
    def self.seen(id, now) = where(id: id).update(last_seen_at: now)

    # Writes the resolved +fields+ of board +id+ (String keys, RecordModel::FIELDS),
    # their +provenance+ and its +delisted+ mark (+delisted_at+ is set to
    # +now+ when it turns delisted, and cleared when it is listed again).
    def self.resolve(id, fields, provenance, delisted, now)
      columns = RecordModel::FIELDS.to_h { |field| [field, fields[field.to_s]] }
      where(id: id).update(**columns, provenance: JSON.generate(provenance), delisted: delisted ? 1 : 0,
                           delisted_at: delisted ? Sequel.function(:coalesce, :delisted_at, now) : nil)
    end

    # Sets the opt-out level of board +id+ (nil, no_preview or hide).
    def self.set_optout(id, level) = where(id: id).update(optout: level)

    # Makes board +id+ an alias of board +canonical+ (nil: none).
    def self.set_alias(id, canonical) = where(id: id).update(alias_of: canonical)

    # The boards with a known address: id, host, port, alias_of, optout, ip
    # and the number of active sources (+sources+).
    def self.addresses
      db.fetch(<<~SQL).all
        SELECT b.id, b.host, b.port, b.alias_of, b.optout, s.ip,
               (SELECT COUNT(*) FROM board_sources bs WHERE bs.board_id = b.id AND bs.active = 1) AS sources
        FROM boards b LEFT JOIN board_state s ON s.board_id = b.id
      SQL
    end

    # The counts of the C64 face's tabs and Sources screen: the shown
    # boards, those online, those that showed PETSCII (measured) and those a
    # list calls PETSCII (claimed), and those more than one list names.
    def self.stats
      tagged = ->(tag) { db.fetch("SELECT COUNT(*) FROM tags WHERE tag = ? AND board_id IN (#{SHOWN})", tag).single_value.to_i }
      {
        boards:  db.fetch("SELECT COUNT(*) FROM (#{SHOWN})").single_value.to_i,
        online:  db.fetch("SELECT COUNT(*) FROM board_state WHERE state = 'online' AND board_id IN (#{SHOWN})").single_value.to_i,
        petscii: tagged.call('petscii'),
        claimed: tagged.call(TagModel::CLAIMS_PETSCII),
        shared:  db.fetch(<<~SQL).single_value.to_i
          SELECT COUNT(*) FROM (SELECT board_id FROM board_sources WHERE active = 1 AND board_id IN (#{SHOWN})
                                GROUP BY board_id HAVING COUNT(*) > 1)
        SQL
      }
    end

    # The boards of the catalog for bin/discovery-report: all of them, the
    # aliases, the delisted and the hidden ones.
    def self.totals
      { total: count, aliases: exclude(alias_of: nil).count, delisted: where(delisted: 1).count,
        hidden: where(optout: 'hide').count }
    end
  end
end
