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
        BAR = 14
        # The name of a list on this screen.
        NAMES = { 'fidonet' => 'FIDONET', 'fsxnet' => 'FSXNET', 'micronet' => 'MICRONET', 'sbl' => 'SBL',
                  'syncterm' => 'SYNCTERM', 'tbg' => 'TBG', 'cbbs' => 'CBBS' }.freeze
        # The name of a list beside a field of a board's page.
        SHORT = { 'fidonet' => 'FIDO', 'fsxnet' => 'FSX', 'micronet' => 'MICRO', 'sbl' => 'SBL',
                  'syncterm' => 'STERM', 'tbg' => 'TBG', 'cbbs' => 'CBBS' }.freeze
        # Its format and what we may do with it.
        TERMS = { 'fidonet' => 'DAILY NODELIST/FACTS', 'fsxnet' => 'WEEKLY NODELIST/FACTS',
                  'micronet' => 'WEEKLY NODELIST/FACTS', 'sbl' => 'HTML EXPORT/CREDIT',
                  'syncterm' => 'SYNCTERM.LST/CREDIT', 'tbg' => 'MONTHLY ZIP/PERMISSION',
                  'cbbs' => 'JSON/FACTS ONLY' }.freeze
        COLORS = { 'cbbs' => Canvas::LIGHT_RED, 'tbg' => Canvas::YELLOW, 'sbl' => Canvas::LIGHT_GREEN,
                   'syncterm' => Canvas::CYAN, 'fidonet' => Canvas::LIGHT_BLUE, 'fsxnet' => Canvas::ORANGE,
                   'micronet' => Canvas::PURPLE }.freeze
        HINT = [['←', true], [' BACK  ', false], ['O', true], [' OWN  ', false], ['D', true], [' DISCOVER', false]].freeze

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
          @sources.each_with_index { |s, i| source(canvas, Layout.row(2 + (2 * i)), s, largest) }
          Layout.rule(canvas, Layout.row(16))
          totals(canvas, Layout.row(17))
          petscii(canvas, Layout.row(18))
          Layout.runs(canvas, Layout.row(20), 1, [['COUNTRIES ', Canvas::GREY], ['DB-IP.COM', Canvas::WHITE]])
          canvas.text(Layout.row(21), 1, 'IP TO COUNTRY LITE, CC BY 4.0', Canvas::GREY)
        end

        private

        def source(canvas, row, source, largest)
          id    = source['id']
          count = source['record_count'].to_i
          canvas.text(row, 1, NAMES.fetch(id) { Layout.plain(id)[0, 9] }, SourcesView.color(id))
          canvas.text(row, 11, bar(count, largest), SourcesView.color(id))
          canvas.text(row, Layout::WIDTH - count.to_s.length, count.to_s, Canvas::WHITE)
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
            canvas.text(row, 5, Layout.plain(source['last_error'])[0, 24], Canvas::LIGHT_RED)
            return
          end
          unless source['last_parse_at']
            canvas.text(row, 1, 'NOT READ YET', Canvas::GREY)
            return
          end

          canvas.text(row, 1, 'OK', Canvas::GREEN, rvs: true)
          age = Layout.age(source['last_parse_at'], @now.call)
          terms = TERMS.fetch(source['id']) { Layout.plain(source['format']) }
          terms = terms[0, Layout::WIDTH - 4 - age.length - 1]
          terms.split('/').each_with_index.reduce(4) do |col, (part, i)|
            col = Layout.runs(canvas, row, col, [['/', Canvas::DARK_GREY]]) if i.positive?
            Layout.runs(canvas, row, col, [[part, Canvas::LIGHT_GREY]])
          end
          canvas.text(row, Layout::WIDTH - age.length, age, Canvas::GREY)
        end

        def totals(canvas, row)
          Layout.runs(canvas, row, 1, [['BOARDS ', Canvas::GREY], [@stats[:boards].to_s, Canvas::WHITE],
                                       ['  SHARED ', Canvas::GREY], [@stats[:shared].to_s, Canvas::WHITE]])
        end

        # PETSCII measured (green) against claimed (purple), and the legend.
        def petscii(canvas, row)
          measured = @stats[:petscii].to_i
          claimed  = @stats[:claimed].to_i
          whole    = [measured, claimed, 1].max
          green    = measured.positive? ? [(measured * BAR.to_f / whole).round, 1].max : 0
          purple   = [(claimed * BAR.to_f / whole).round - green, 0].max
          canvas.text(row, 1, 'PETSCII', Canvas::GREY)
          canvas.text(row, 9, '█' * green, Canvas::GREEN)
          canvas.text(row, 9 + green, '▒' * purple, Canvas::PURPLE)
          count = "#{measured}/#{claimed}"
          canvas.text(row, Layout::WIDTH - count.length, count, Canvas::WHITE)
          Layout.runs(canvas, row + 1, 9, [['█', Canvas::GREEN], [' MEASURED  ', Canvas::LIGHT_GREY], ['▒', Canvas::PURPLE],
                                           [' CLAIMED', Canvas::LIGHT_GREY]])
        end
      end
    end
  end
end
