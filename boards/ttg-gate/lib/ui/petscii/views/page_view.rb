# frozen_string_literal: true

require_relative 'picker'

module UI
  module Petscii
    module Views
      # The page of one board of Global Discovery: its address, the last
      # answer, the 30-day uptime strip, the fields with the list each came
      # from, the tag chips, and the buttons. RETURN dials it (+on_dial+), B
      # shows its PETSCII banner (+on_banner+).
      class PageView < View
        WHY = {
          'dns_fail' => 'Name does not resolve', 'timeout' => 'No answer (firewall?)',
          'refused' => 'Port closed', 'closed' => 'Hung up at once'
        }.freeze
        STRIP = { ::Discovery::BoardPageModel::UP => ['█', Canvas::GREEN],
                  ::Discovery::BoardPageModel::DOWN => ['█', Canvas::RED] }.freeze
        NO_DAY = ['▒', Canvas::DARK_GREY].freeze
        HINT = [['RETURN', true], [' Dial  ', false], ['B', true], [' Banner  ', false], ['←', true],
                [' Back', false]].freeze
        FIELDS = 8
        # The column of a field's value, and the rows a long one wraps to.
        VALUE = 10
        VALUE_ROWS = 2
        # The rows of the tag chips, the buttons, the banner note and the
        # opt-out link, from the top of the content.
        TAGS_LINE = 16
        WIKI = 'wiki.teletypegames.org'

        attr_reader :page, :section

        def initialize(page, section:, on_dial:, on_banner:, now: -> { Time.now.to_i })
          super()
          @page      = page
          @section   = section
          @on_dial   = on_dial
          @on_banner = on_banner
          @now       = now
        end

        def listing = @page.listing

        def replace(page) = @page = page

        # Whether there is a banner the C64 can show: a PETSCII one, of the
        # C64-style call or of the scheduled one.
        def banner? = !@page.c64_banner.nil?

        def hint
          return HINT[4, 2] unless listing.c64?

          banner? ? HINT : HINT[0, 2] + HINT[4, 2]
        end

        def handle(key)
          case key
          when :enter then -> { @on_dial.call(listing) }
          when 'b', 'B' then banner? ? -> { @on_banner.call(@page) } : :redraw
          end
        end

        def draw(canvas)
          down = head(canvas)
          answer(canvas, Layout.row(2 + down))
          strip(canvas, Layout.row(4 + down))
          fields(canvas, Layout.row(7 + down), Layout.row(TAGS_LINE - 1))
          tags(canvas, Layout.row(TAGS_LINE))
          buttons(canvas, Layout.row(TAGS_LINE + 2))
          footer(canvas, TAGS_LINE + 3)
        end

        private

        # The band and the address; the rows a long address took beyond one.
        def head(canvas)
          color = ListView::STATE_COLORS.fetch(listing.state, Canvas::LIGHT_GREY)
          Layout.band(canvas, Layout.plain(listing.title), listing.state.capitalize, color)
          Layout.address(canvas, Layout.row(1), 1, listing.host, listing.port) - 1
        end

        # The banner note and the opt-out link.
        def footer(canvas, line)
          canvas.text(Layout.row(line), 1, banner_note, Canvas::GREY)
          Layout.runs(canvas, Layout.row(line + 1), 1, [['Opt-out/policy: ', Canvas::DARK_GREY], [WIKI, Canvas::GREY]])
        end

        def answer(canvas, row)
          if !listing.first_probe_at
            canvas.text(row, 1, 'Not called yet', Canvas::LIGHT_GREY)
          elsif !@page.last_success_at
            canvas.text(row, 1, 'Never answered', Canvas::LIGHT_RED)
          else
            latency = @page.latency_ms && listing.state == 'online' ? "  #{@page.latency_ms} ms" : ''
            Layout.runs(canvas, row, 1, [['Last OK ', Canvas::GREY], [ago(@page.last_success_at), Canvas::WHITE],
                                         [latency, Canvas::LIGHT_GREY]])
          end
          why = WHY[@page.last_result] if %w[down dead flaky].include?(listing.state)
          Layout.runs(canvas, row + 1, 1, [['From us ', Canvas::DARK_GREY], [why, Canvas::LIGHT_RED]]) if why
        end

        def ago(at)
          seconds = [@now.call - at, 0].max
          return 'just now' if seconds < 60
          return "#{seconds / 60} min ago" if seconds < 3600
          return "#{seconds / 3600} hours ago" if seconds < 2 * 86_400

          "#{seconds / 86_400} days ago"
        end

        def strip(canvas, row)
          days = @page.strip(@now.call)
          up = days.count(::Discovery::BoardPageModel::UP)
          canvas.text(row, 1, '30 days', Canvas::GREY)
          right = "#{up}/#{days.length}"
          days.each_char.with_index do |day, i|
            glyph, color = STRIP.fetch(day, NO_DAY)
            canvas.text(row + 1, 1 + i, glyph, color)
          end
          canvas.text(row + 1, days.length + 3, right, up.positive? ? Canvas::LIGHT_GREEN : Canvas::LIGHT_RED)
        end

        # The fields with a value from +row+ to +last+: the label, the value
        # (a long one wraps), and in dark grey the list it came from; the
        # terminals and the lists last.
        def fields(canvas, row, last)
          extra = []
          extra << ['Terminal', terminals, 'CALL'] if terminals.any?
          extra << ['Sources', lists, ''] if lists.any?
          row = listed(canvas, row, last - row + 1 - extra.size, FIELDS - extra.size)
          extra.each_with_index do |(label, parts, source), i|
            field(canvas, row + i, label, source)
            Layout.runs(canvas, row + i, VALUE, parts, limit: limit(source))
          end
        end

        # At most +count+ fields of the lists in +room+ rows from +row+;
        # the row after them.
        def listed(canvas, row, room, count)
          shown = @page.fields.reject { |f| %w[Name Encoding Website].include?(f.label) }
          shown.first(count).each do |f|
            break if room <= 0

            used = value(canvas, row, f, room)
            row += used
            room -= used
          end
          row
        end

        # One field at +row+, its value wrapped into at most +room+ rows; the
        # rows it took.
        def value(canvas, row, field, room)
          source = short(field)
          lines = Layout.wrap(field.value, limit(source) - VALUE, [VALUE_ROWS, room].min)
          field(canvas, row, Layout.plain(field.label.sub('FTN address', 'FTN')), source)
          lines.each_with_index { |line, i| canvas.text(row + i, VALUE, line, Canvas::WHITE) }
          lines.size
        end

        def field(canvas, row, label, source)
          canvas.text(row, 1, label[0, VALUE - 2], Canvas::GREY)
          canvas.text(row, Layout::EDGE - source.length, source, Canvas::DARK_GREY) unless source.empty?
        end

        # The column a value stops before, the source's name after it.
        def limit(source) = Layout::EDGE - (source.empty? ? 0 : source.length + 1)

        def terminals
          @terminals ||= begin
            terms = ListView::TERMINALS.keys.select { |t| listing.tags.include?(t) }.sort_by { |t| t == 'petscii' ? 0 : 1 }
            terms.each_with_index.flat_map do |t, i|
              [(['+', Canvas::DARK_GREY] if i.positive?), [t.upcase, ListView::TERMINALS[t]]].compact
            end
          end
        end

        def lists
          @lists ||= @page.sources.select { |s| s['active'] == 1 }.each_with_index.flat_map do |s, i|
            id = s['source_id']
            [(['/', Canvas::DARK_GREY] if i.positive?), [SourcesView::SHORT.fetch(id, id.upcase), SourcesView.color(id)]].compact
          end
        end

        # The list a field came from, short.
        def short(field)
          case field.source
          when nil then ''
          when 'our call' then field.label == 'Software' ? 'BANNER' : 'CALL'
          when 'DB-IP' then 'DB-IP'
          else
            id = @page.sources.find { |s| s['name'].to_s.sub(/\s*\([^)]*\)\z/, '') == field.source }&.dig('source_id')
            id ? SourcesView::SHORT.fetch(id, id.upcase) : Layout.plain(field.source)[0, 6]
          end
        end

        def tags(canvas, row)
          chips = terminals.reject { |part| part.first == '+' }
          chips << ["CC:#{listing.country.upcase}", Canvas::ORANGE] if listing.country
          listing.tags.grep(/\Anet:/).each { |t| chips << [Layout.plain(t), Canvas::LIGHT_RED] }
          col = 1
          chips.each { |text, color| col = Layout.chip(canvas, row, col, text, color) + 1 }
        end

        def buttons(canvas, row)
          return canvas.text(row, 1, 'No PETSCII or ASCII: no dial', Canvas::LIGHT_RED) unless listing.c64?

          col = Layout.chip(canvas, row, 1, 'RETURN', Canvas::LIGHT_GREEN)
          col = Layout.chip(canvas, row, col, 'Dial', Canvas::GREEN) + 2
          return canvas.text(row, col, 'ASCII, translated', Canvas::LIGHT_GREY) if listing.translated_for_c64?
          return canvas.text(row, col, 'No banner', Canvas::DARK_GREY) unless banner?

          col = Layout.chip(canvas, row, col, 'B', Canvas::YELLOW)
          Layout.chip(canvas, row, col, 'Banner', Canvas::ORANGE)
        end

        def banner_note
          return 'Banner hidden by the sysop' unless listing.preview?
          return 'Banner: PETSCII, B shows it' if banner?
          return 'No banner stored yet' unless @page.banner

          "#{@page.encoding.to_s.upcase} banner: modern face"
        end
      end
    end
  end
end
