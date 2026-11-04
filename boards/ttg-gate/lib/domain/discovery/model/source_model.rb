# frozen_string_literal: true

module Discovery
  # A source list in the catalog: its config (a SourceConfigModel) and how
  # its last fetch, parse and import went.
  class SourceModel < BBS::Model
    table :sources, database: :discovery

    # The columns a source's config gives.
    CONFIG = %i[name url format licence attribution].freeze

    # Every source, by id: its rows as Hashes.
    def self.ordered = order(:id).naked.all

    # Writes the config of +source+ (a SourceConfigModel), the row made when
    # missing, and +changes+ (columns).
    def self.save_config(source, **changes)
      config = CONFIG.to_h { |column| [column, source.public_send(column)] }
      dataset.insert_conflict(target: :id, update: CONFIG.to_h { |column| [column, Sequel[:excluded][column]] })
             .insert(id: source.id, **config)
      where(id: source.id).update(changes) unless changes.empty?
    end

    # Every source id, in order.
    def self.ids = order(:id).select_map(:id)

    # The sources for bin/discovery-report: id, record_count, last_error,
    # the boards it lists now (+active+) and those only it lists (+only+).
    def self.coverage
      db.fetch(<<~SQL).all
        SELECT s.id, s.record_count, s.last_error,
          (SELECT COUNT(*) FROM board_sources bs WHERE bs.source_id = s.id AND bs.active = 1) AS active,
          (SELECT COUNT(*) FROM board_sources bs WHERE bs.source_id = s.id AND bs.active = 1 AND NOT EXISTS
             (SELECT 1 FROM board_sources o WHERE o.board_id = bs.board_id AND o.source_id != s.id AND o.active = 1)) AS only
        FROM sources s ORDER BY s.id
      SQL
    end
  end
end
