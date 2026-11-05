# frozen_string_literal: true

module UI
  module Petscii
    module Sysop
      # The gate's last log lines (Rubbs::Common::Log.recent), the newest at the
      # bottom, a row each cut at the edge; redrawn every two seconds. CRSR
      # scrolls back, F keeps the warnings and errors, / the lines with a
      # word.
      class LogView < Views::View
        include Shared

        COLORS = {
          debug: Canvas::GREY,
          info:  Canvas::LIGHT_GREY,
          warn:  Canvas::YELLOW,
          error: Canvas::LIGHT_RED,
          fatal: Canvas::LIGHT_RED
        }.freeze
        HINT = [['CRSR', true], [' Scroll  ', false], ['F', true], [' Warn  ', false], ['/', true], [' Find  ', false],
                ['←', true], [' Back', false]].freeze
        SHOWN = Layout::ROWS - 2

        every(2) { redraw }

        key(:up) { @back = (@back + 1).clamp(0, most) }
        key(:down) { @back = [@back - 1, 0].max }
        key('+') { @back = [@back - SHOWN, 0].max }
        key('-') { @back = (@back + SHOWN).clamp(0, most) }
        key('f', 'F') { @serious = !@serious }
        key('/') { search }

        def initialize(_accounts)
          super()
          @back    = 0
          @serious = false
          @query   = nil
        end

        def section = :log

        def hint = HINT

        def draw(canvas)
          list  = entries
          @back = @back.clamp(0, [list.size - SHOWN, 0].max)
          shown = list[[list.size - SHOWN - @back, 0].max, SHOWN].to_a
          right = [(@serious ? 'warn' : 'all'), @query, (@back.positive? ? "-#{@back}" : nil)].compact.join(' ')
          Layout.band(canvas, 'LOG', right, Canvas::YELLOW)
          shown.each_with_index do |entry, i|
            canvas.text(Layout.row(1 + i), 0, Layout.plain(text(entry))[0, Layout::EDGE], COLORS.fetch(entry.level, Canvas::LIGHT_GREY))
          end
        end

        private

        def entries
          list = Rubbs::Common::Log.recent
          list = list.reject { |e| %i[debug info].include?(e.level) } if @serious
          list = list.select { |e| text(e).downcase.include?(@query.downcase) } if @query
          list
        end

        def most = [entries.size - SHOWN, 0].max

        def text(entry)
          facts = entry.fields.except(:session, :ip, :event, :asker).map { |k, v| "#{k}=#{v}" }.join(' ')
          "#{entry.time.strftime('%H:%M')} #{entry.tag}: #{entry.message} #{facts}".strip
        end

        def search
          text = read_line('Find:', text: @query.to_s, max: 20)&.strip
          return if text.nil?

          @query = text.empty? ? nil : text
          @back  = 0
        end
      end
    end
  end
end
