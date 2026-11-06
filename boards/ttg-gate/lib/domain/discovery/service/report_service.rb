# frozen_string_literal: true

module Discovery
  # The text of bin/discovery-report: the boards a source and their overlap,
  # the states, and the commonest tags.
  class ReportService
    def text
      lines = [boards]
      lines << '' << sources_table << '' << overlap_table << '' << states << '' << petscii << '' << tags
      lines.join("\n")
    end

    private

    def boards
      n = BoardModel.totals
      "Boards: #{n[:total]} (#{n[:total] - n[:aliases]} after aliases; #{n[:aliases]} aliases, #{n[:delisted]} delisted, " \
        "#{n[:hidden]} hidden)"
    end

    def sources_table
      out = [row('Source', 'Records', 'Boards', 'Only', 'Last error')]
      SourceModel.coverage.each do |r|
        out << row(r[:id], r[:record_count].to_i, r[:active], r[:only], r[:last_error] || '-')
      end
      out.join("\n")
    end

    def row(name, *numbers, note) = [name.to_s.ljust(10), *numbers.map { |n| n.to_s.rjust(8) }, " #{note}"].join(' ')

    def overlap_table
      ids = SourceModel.ids
      pairs = BoardSourceModel.overlap
      out = ['Overlap (boards in both)', cells('', ids)]
      ids.each { |a| out << cells(a, ids.map { |b| pairs.fetch([a, b], 0) }) }
      out << "In more than one source: #{BoardSourceModel.shared}"
      out.join("\n")
    end

    def cells(name, values) = [name.ljust(10), *values.map { |v| v.to_s.rjust(9) }].join(' ')

    def states
      ["States: #{BoardStateModel.report.map { |state, n| "#{state} #{n}" }.join(', ')}",
       "Probes: #{ProbeModel.results.map { |result, n| "#{result} #{n}" }.join(', ')}"].join("\n")
    end

    # PETSCII measured against claimed: the boards a source calls PETSCII,
    # how many of them had a C64-style call, how many showed PETSCII, and the
    # boards with PETSCII no source claims.
    def petscii
      row = TagModel.petscii
      "PETSCII: #{row[:claimed]} claimed by a source, #{row[:called]} called as a C64, #{row[:measured]} of them " \
        "PETSCII, #{row[:other]} ANSI/ASCII to a C64; #{row[:unclaimed]} PETSCII without a claim"
    end

    def tags = "Tags: #{TagModel.commonest(40).map { |tag, n| "#{tag} #{n}" }.join(', ')}"
  end
end
