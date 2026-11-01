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
        FIELDS = 5
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

        def hint = banner? ? HINT : HINT[0, 2] + HINT[4, 2]

        def handle(key)
          case key
          when :enter then -> { @on_dial.call(listing) }
          when 'b', 'B' then banner? ? -> { @on_banner.call(@page) } : :redraw
          end
        end

        def draw(canvas)
          color = ListView::STATE_COLORS.fetch(listing.state, Canvas::LIGHT_GREY)
          Layout.band(canvas, Layout.plain(listing.title), listing.state.capitalize, color)
          down = Layout.address(canvas, Layout.row(2), 1, listing.host, listing.port) - 1
          answer(canvas, Layout.row(3 + down))
          strip(canvas, Layout.row(5 + down))
          fields(canvas, Layout.row(8 + down))
          tags(canvas, Layout.row(14 + down))
          buttons(canvas, Layout.row(16 + down))
          footer(canvas, 18 + down)
        end

        private

        # The banner note, and the opt-out link while there is room: a long
        # address pushes them down.
        def footer(canvas, line)
          last = Layout::ROWS - 1
          canvas.text(Layout.row(line), 1, banner_note, Canvas::GREY) if line <= last
          return unless line + 2 <= last

          canvas.text(Layout.row(line + 1), 1, 'Opt-out, probe policy:', Canvas::DARK_GREY)
          canvas.text(Layout.row(line + 2), 1, WIKI, Canvas::GREY)
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
          canvas.text(row, Layout::WIDTH - 1 - right.length, right, up.positive? ? Canvas::LIGHT_GREEN : Canvas::LIGHT_RED)
          days.each_char.with_index do |day, i|
            glyph, color = STRIP.fetch(day, NO_DAY)
            canvas.text(row + 1, i, glyph, color)
          end
        end

        # The fields with a value, a row each: the label, the value, and in
        # dark grey the list it came from; the terminals and the lists last.
        def fields(canvas, row)
          shown = @page.fields.reject { |f| %w[Name Encoding Website].include?(f.label) }
          lines = shown.map { |f| [Layout.plain(f.label.sub('FTN address', 'FTN')), [[Layout.plain(f.value), Canvas::WHITE]], short(f)] }
          extra = []
          extra << ['Terminal', terminals, 'CALL'] if terminals.any?
          extra << ['Sources', lists, ''] if lists.any?
          (lines.first(FIELDS - extra.size) + extra).each do |label, parts, source|
            canvas.text(row, 1, label[0, 8], Canvas::GREY)
            limit = Layout::WIDTH - 1 - (source.empty? ? 0 : source.length + 1)
            Layout.runs(canvas, row, 10, parts, limit: limit)
            canvas.text(row, Layout::WIDTH - 1 - source.length, source, Canvas::DARK_GREY) unless source.empty?
            row += 1
          end
        end

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
          col = Layout.chip(canvas, row, 1, 'RETURN', Canvas::LIGHT_GREEN)
          col = Layout.chip(canvas, row, col, 'Dial', Canvas::GREEN) + 2
          return canvas.text(row, col, 'No banner', Canvas::DARK_GREY) unless banner?

          col = Layout.chip(canvas, row, col, 'B', Canvas::YELLOW)
          Layout.chip(canvas, row, col, 'Banner', Canvas::ORANGE)
        end

        def banner_note
          return 'Banner hidden by the sysop' unless listing.preview?
          return 'Banner: PETSCII, B shows it' if banner?
          return 'No banner stored yet' unless @page.banner

          "#{@page.encoding.to_s.upcase} banner: modern face"[0, 28]
        end
      end
    end
  end
end
