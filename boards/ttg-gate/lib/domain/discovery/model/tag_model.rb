# frozen_string_literal: true

module Discovery
  # A tag of a board (TagService): what a search and Browse find it by.
  class TagModel < BBS::Model
    table :tags, database: :discovery

    # The tag of a board a source says is a PETSCII board.
    CLAIMS_PETSCII = 'claims:petscii'

    # The tags of board +board_id+, sorted.
    def self.of(board_id) = where(board_id: board_id).order(:tag).select_map(:tag)

    # Makes +tags+ the tags of board +board_id+. One transaction.
    def self.replace(board_id, tags)
      db.transaction do
        where(board_id: board_id).delete
        import(%i[board_id tag], tags.uniq.map { |tag| [board_id, tag] }) if tags.any?
      end
    end

    # Every tag a board has: the vocabulary of the search.
    def self.vocabulary = distinct.select_map(:tag)

    # The +limit+ commonest tags, the commonest first: [tag, n] pairs.
    def self.commonest(limit)
      group_and_count(:tag).order(Sequel.desc(:count), :tag).limit(limit).naked.map { |r| [r[:tag], r[:count]] }
    end

    # PETSCII measured against claimed (aliases apart): the boards a source
    # calls PETSCII (+claimed+), how many of them had a C64-style call
    # (+called+), how many showed PETSCII (+measured+) and how many were
    # ANSI or ASCII to a C64 (+other+); and the boards with PETSCII no source
    # claims (+unclaimed+).
    def self.petscii
      row = db.fetch(<<~SQL).first
        SELECT COUNT(*) AS claimed,
          COUNT(*) FILTER (WHERE s.c64_probe_at IS NOT NULL) AS called,
          COUNT(*) FILTER (WHERE b.id IN (SELECT board_id FROM tags WHERE tag = 'petscii')) AS measured,
          COUNT(*) FILTER (WHERE s.c64_encoding IN ('ansi', 'ascii')) AS other
        FROM boards b JOIN tags t ON t.board_id = b.id AND t.tag = 'claims:petscii'
        LEFT JOIN board_state s ON s.board_id = b.id WHERE b.alias_of IS NULL
      SQL
      row.merge(unclaimed: db.fetch(<<~SQL).single_value)
        SELECT COUNT(*) FROM tags t JOIN boards b ON b.id = t.board_id WHERE t.tag = 'petscii' AND b.alias_of IS NULL
          AND b.id NOT IN (SELECT board_id FROM tags WHERE tag = 'claims:petscii')
      SQL
    end
  end
end
