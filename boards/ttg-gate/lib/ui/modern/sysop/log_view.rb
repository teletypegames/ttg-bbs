# frozen_string_literal: true

module UI
  module Modern
    module Sysop
      # The gate's last log lines (BBS::Log.recent), the newest at the
      # bottom, redrawn every two seconds: logins, bans, dials and errors.
      # The arrows scroll back, F shows warnings and errors only, / keeps
      # the lines that have a word, END comes back to the newest.
      class LogView < View
        LEVEL_COLORS = {
          debug: BBS::Kit::Modern::Palette::DIM,
          info:  BBS::Kit::Modern::Palette::TEXT,
          warn:  BBS::Kit::Modern::Palette::YELLOW,
          error: BBS::Kit::Modern::Palette::RED,
          fatal: BBS::Kit::Modern::Palette::RED
        }.freeze

        every(2) { redraw }

        key(:up) { @back = (@back + 1).clamp(0, most) }
        key(:down) { @back = [@back - 1, 0].max }
        key(:page_up) { @back = (@back + per_page).clamp(0, most) }
        key(:page_down) { @back = [@back - per_page, 0].max }
        key(:end) { @back = 0 }
        key('f', 'F') { @serious = !@serious }
        key('/') { search }

        def initialize(accounts)
          super
          @back    = 0
          @serious = false
          @query   = nil
        end

        private

        def entries
          list = BBS::Log.recent
          list = list.reject { |e| %i[debug info].include?(e.level) } if @serious
          list = list.select { |e| line_text(e).downcase.include?(@query.downcase) } if @query
          list
        end

        def most = [entries.size - per_page, 0].max

        def body
          list  = entries
          @back = @back.clamp(0, [list.size - per_page, 0].max)
          shown = list[[list.size - per_page - @back, 0].max, per_page].to_a
          right = [@serious ? 'warnings and errors' : 'all lines']
          right << "“#{@query}”" if @query
          right << "#{@back} back" if @back.positive?
          right = right.join('  ·  ')
          [crumbs('LOG', right), *shown.map { |e| row(e) }]
        end

        def row(entry)
          "#{DIM}#{entry.time.strftime('%H:%M:%S')}#{RESET} #{LEVEL_COLORS.fetch(entry.level, TEXT)}" \
            "#{fit(line_text(entry), width - 9)}#{RESET}"
        end

        def line_text(entry)
          facts = entry.fields.map { |k, v| "#{k}=#{v}" }.join(' ')
          "#{entry.tag}: #{entry.message} #{facts}".strip
        end

        def hints = '↑↓ PgUp PgDn scroll   END newest   F warnings only   / search   TAB next   Q back'

        def tab = :log

        def per_page = [rows - 8, 3].max

        def search
          text = read_line('Search:', text: @query.to_s, max: 40, hint: 'A word of the lines: login ban door …')
          return if text.nil?

          @query = text.strip.empty? ? nil : text.strip
          @back  = 0
        end
      end
    end
  end
end
