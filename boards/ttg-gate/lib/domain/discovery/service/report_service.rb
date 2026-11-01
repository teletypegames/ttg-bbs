# frozen_string_literal: true

module Discovery
  # The text of bin/discovery-report: the boards a source and their overlap,
  # the states, and the commonest tags.
  class ReportService
    def initialize(db)
      @db = db
    end

    def text
      lines = []
      total = @db.value('SELECT COUNT(*) FROM boards')
      aliases = @db.value('SELECT COUNT(*) FROM boards WHERE alias_of IS NOT NULL')
      delisted = @db.value('SELECT COUNT(*) FROM boards WHERE delisted = 1')
      hidden = @db.value("SELECT COUNT(*) FROM boards WHERE optout = 'hide'")
      lines << "Boards: #{total} (#{total - aliases} after aliases; #{aliases} aliases, #{delisted} delisted, #{hidden} hidden)"
      lines << '' << sources_table << '' << overlap_table << '' << states << '' << tags
      lines.join("\n")
    end

    private

    def source_ids = @db.query('SELECT id FROM sources ORDER BY id').map { |r| r['id'] }

    def sources_table
      rows = @db.query(<<~SQL)
        SELECT s.id, s.record_count, s.last_error,
          (SELECT COUNT(*) FROM board_sources bs WHERE bs.source_id = s.id AND bs.active = 1) AS active,
          (SELECT COUNT(*) FROM board_sources bs WHERE bs.source_id = s.id AND bs.active = 1 AND NOT EXISTS
             (SELECT 1 FROM board_sources o WHERE o.board_id = bs.board_id AND o.source_id != s.id AND o.active = 1)) AS only
        FROM sources s ORDER BY s.id
      SQL
      out = [row('Source', 'Records', 'Boards', 'Only', 'Last error')]
      rows.each do |r|
        out << row(r['id'], r['record_count'].to_i, r['active'], r['only'], r['last_error'] || '-')
      end
      out.join("\n")
    end

    def row(name, *numbers, note) = [name.to_s.ljust(10), *numbers.map { |n| n.to_s.rjust(8) }, " #{note}"].join(' ')

    def overlap_table
      ids = source_ids
      pairs = @db.query(<<~SQL).to_h { |r| [[r['a'], r['b']], r['n']] }
        SELECT a.source_id AS a, b.source_id AS b, COUNT(*) AS n
        FROM board_sources a JOIN board_sources b ON a.board_id = b.board_id
        WHERE a.active = 1 AND b.active = 1 GROUP BY 1, 2
      SQL
      out = ['Overlap (boards in both)', cells('', ids)]
      ids.each { |a| out << cells(a, ids.map { |b| pairs.fetch([a, b], 0) }) }
      multi = @db.value(<<~SQL)
        SELECT COUNT(*) FROM (SELECT board_id FROM board_sources WHERE active = 1 GROUP BY board_id HAVING COUNT(*) > 1)
      SQL
      out << "In more than one source: #{multi}"
      out.join("\n")
    end

    def cells(name, values) = [name.ljust(10), *values.map { |v| v.to_s.rjust(9) }].join(' ')

    def states
      rows = @db.query(<<~SQL)
        SELECT CASE WHEN COALESCE(s.archived, 0) = 1 THEN 'archived' ELSE COALESCE(s.state, 'unknown') END AS state,
               COUNT(*) AS n
        FROM boards b LEFT JOIN board_state s ON s.board_id = b.id WHERE b.alias_of IS NULL GROUP BY 1 ORDER BY 2 DESC
      SQL
      results = @db.query('SELECT result, COUNT(*) AS n FROM probes GROUP BY 1 ORDER BY 2 DESC')
      ["States: #{rows.map { |r| "#{r['state']} #{r['n']}" }.join(', ')}",
       "Probes: #{results.map { |r| "#{r['result']} #{r['n']}" }.join(', ')}"].join("\n")
    end

    def tags
      rows = @db.query('SELECT tag, COUNT(*) AS n FROM tags GROUP BY tag ORDER BY n DESC, tag LIMIT 40')
      "Tags: #{rows.map { |r| "#{r['tag']} #{r['n']}" }.join(', ')}"
    end
  end
end
