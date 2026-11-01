# frozen_string_literal: true

require_relative 'picker'

module UI
  module Petscii
    module Views
      # Where the catalog comes from: a list two rows each (its name in its
      # own colour, a bar of its records against the largest list's, the
      # count; whether its last import went well, its format and terms, how
      # long ago), then the totals, PETSCII measured against claimed, and
      # the credit of DB-IP for the countries.
      class SourcesView < View
        BAR = 21
        BAR_COL = 11
        # The name of a list on this screen.
        NAMES = { 'fidonet' => 'FidoNet', 'fsxnet' => 'fsxNet', 'micronet' => 'MicroNet', 'sbl' => 'SBL',
                  'syncterm' => 'SyncTERM', 'tbg' => 'TBG', 'cbbs' => 'CBBS' }.freeze
        # The name of a list beside a field of a board's page.
        SHORT = { 'fidonet' => 'FIDO', 'fsxnet' => 'FSX', 'micronet' => 'MICRO', 'sbl' => 'SBL',
                  'syncterm' => 'STERM', 'tbg' => 'TBG', 'cbbs' => 'CBBS' }.freeze
        # Its format and what we may do with it.
        TERMS = { 'fidonet' => 'daily nodelist/facts', 'fsxnet' => 'weekly nodelist/facts',
                  'micronet' => 'weekly nodelist/facts', 'sbl' => 'HTML export/credit',
                  'syncterm' => 'syncterm.lst/credit', 'tbg' => 'monthly ZIP/permission',
                  'cbbs' => 'JSON/facts only' }.freeze
        COLORS = { 'cbbs' => Canvas::LIGHT_RED, 'tbg' => Canvas::YELLOW, 'sbl' => Canvas::LIGHT_GREEN,
                   'syncterm' => Canvas::CYAN, 'fidonet' => Canvas::LIGHT_BLUE, 'fsxnet' => Canvas::ORANGE,
                   'micronet' => Canvas::PURPLE }.freeze
        HINT = [['←', true], [' Back  ', false], ['O', true], [' Own  ', false], ['D', true], [' Discover', false]].freeze

        def self.color(id) = COLORS.fetch(id, Canvas::LIGHT_GREY)

        # [sources] the rows of the sources table
        # [stats]   BrowseService#stats
        def initialize(sources, stats, now: -> { Time.now.to_i })
          super()
          @sources = sources.sort_by { |s| [-s['record_count'].to_i, s['id']] }.first(7)
          @stats   = stats
          @now     = now
        end

        def section = :sources

        def hint = HINT

        def draw(canvas)
          Layout.band(canvas, 'SOURCES', "#{@sources.size} LISTS", Canvas::CYAN)
          largest = @sources.map { |s| s['record_count'].to_i }.max.to_i
          @sources.each_with_index { |s, i| source(canvas, Layout.row(1 + (2 * i)), s, largest) }
          Layout.rule(canvas, Layout.row(15))
          totals(canvas, Layout.row(16))
          petscii(canvas, Layout.row(17))
          Layout.runs(canvas, Layout.row(19), 1, [['Countries ', Canvas::GREY], ['db-ip.com', Canvas::WHITE]])
          canvas.text(Layout.row(20), 1, 'IP to Country Lite, CC BY 4.0', Canvas::GREY)
        end

        private

        def source(canvas, row, source, largest)
          id    = source['id']
          count = source['record_count'].to_i
          canvas.text(row, 1, NAMES.fetch(id) { Layout.plain(id)[0, 9] }, SourcesView.color(id))
          canvas.text(row, BAR_COL, bar(count, largest), SourcesView.color(id))
          canvas.text(row, Layout::EDGE - count.to_s.length, count.to_s, Canvas::WHITE)
          status(canvas, row + 1, source)
        end

        # The bar of +count+ against +largest+: BAR cells for the largest,
        # a half cell the finest step.
        def bar(count, largest)
          return '' unless count.positive? && largest.positive?

          halves = [(count * BAR * 2.0 / largest).round, 1].max
          ('█' * (halves / 2)) + (halves.odd? ? '▌' : '')
        end

        def status(canvas, row, source)
          if source['last_error']
            canvas.text(row, 1, 'ERR', Canvas::RED, rvs: true)
            canvas.text(row, 5, Layout.plain(source['last_error'])[0, Layout::EDGE - 5], Canvas::LIGHT_RED)
          elsif source['last_parse_at'] then read(canvas, row, source)
          else
            canvas.text(row, 1, 'Not read yet', Canvas::GREY)
          end
        end

        # OK, the terminals the list names, and how long ago it was read.
        def read(canvas, row, source)
          canvas.text(row, 1, 'OK', Canvas::GREEN, rvs: true)
          age = "read #{Layout.age(source['last_parse_at'], @now.call)} ago"
          terms = TERMS.fetch(source['id']) { Layout.plain(source['format']) }
          terms[0, Layout::EDGE - 4 - age.length - 1].split('/').each_with_index.reduce(4) do |col, (part, i)|
            col = Layout.runs(canvas, row, col, [['/', Canvas::DARK_GREY]]) if i.positive?
            Layout.runs(canvas, row, col, [[part, Canvas::LIGHT_GREY]])
          end
          canvas.text(row, Layout::EDGE - age.length, age, Canvas::GREY)
        end

        def totals(canvas, row)
          Layout.runs(canvas, row, 1, [['Boards ', Canvas::GREY], [@stats[:boards].to_s, Canvas::WHITE],
                                       ['  shared ', Canvas::GREY], [@stats[:shared].to_s, Canvas::WHITE]])
        end

        # PETSCII measured (green) against claimed (purple), and the legend.
        def petscii(canvas, row)
          measured = @stats[:petscii].to_i
          claimed  = @stats[:claimed].to_i
          green, purple = petscii_bars(measured, claimed)
          canvas.text(row, 1, 'PETSCII', Canvas::GREY)
          canvas.text(row, BAR_COL, '█' * green, Canvas::GREEN)
          canvas.text(row, BAR_COL + green, '▒' * purple, Canvas::PURPLE)
          count = "#{measured}/#{claimed}"
          canvas.text(row, Layout::EDGE - count.length, count, Canvas::WHITE)
          Layout.runs(canvas, row + 1, BAR_COL, [['█', Canvas::GREEN], [' measured  ', Canvas::LIGHT_GREY], ['▒', Canvas::PURPLE],
                                                 [' claimed', Canvas::LIGHT_GREY]])
        end

        # The cells of the measured (green) and the claimed-only (purple) bar.
        def petscii_bars(measured, claimed)
          whole  = [measured, claimed, 1].max
          green  = measured.positive? ? [(measured * BAR.to_f / whole).round, 1].max : 0
          [green, [(claimed * BAR.to_f / whole).round - green, 0].max]
        end
      end
    end
  end
end
