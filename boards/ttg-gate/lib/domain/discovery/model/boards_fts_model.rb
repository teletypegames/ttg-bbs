# frozen_string_literal: true

module Discovery
  # The full-text index of the boards (FTS5), a row a board by its id
  # (rowid): its name, sysop, location, software and host.
  class BoardsFtsModel < BBS::Model
    table :boards_fts, database: :discovery

    # Writes the row of board +board_id+: the name, sysop, location, the
    # software (the banner's when known, else the source's) and the host.
    def self.index(board_id)
      row = db.fetch(<<~SQL, board_id).first
        SELECT b.name, b.sysop, b.location, COALESCE(s.software, b.software) AS software, b.host
        FROM boards b LEFT JOIN board_state s ON s.board_id = b.id WHERE b.id = ?
      SQL
      return unless row

      db.transaction do
        where(rowid: board_id).delete
        insert(rowid: board_id, **row)
      end
    end

    # The board ids whose row matches an FTS5 +query+; raises
    # Sequel::DatabaseError on a query FTS5 cannot read.
    def self.search(query) = where(Sequel.lit('boards_fts MATCH ?', query)).select_map(:rowid)
  end
end
