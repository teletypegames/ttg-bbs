# frozen_string_literal: true

require_relative 'picker'

module UI
  module Petscii
    module Views
      # A menu in the main area: Browse and its axes (Software, Country,
      # Network). An entry a row (its number, its name, a dotted leader, its
      # count), the lit one a cyan bar, and under a rule what the lit entry
      # is about. RETURN or its digit takes it (the entry's action).
      class MenuView < Picker
        PER_PAGE = 12
        HINT = [['CRSR', true], [' MOVE  ', false], ['RETURN', true], [' OPEN  ', false]].freeze

        # An entry: its +name+, the +count+ at the edge, the lines it is
        # +about+, and its +action+.
        Entry = Data.define(:name, :count, :about, :action)

        def initialize(entries, title:, color:, section:, empty: 'NOTHING HERE YET.')
          super(entries, per_page: PER_PAGE)
          @title   = title
          @color   = color
          @section = section
          @empty   = empty
        end

        attr_reader :section, :title

        def take(entry) = entry.action

        def hint = pages > 1 ? HINT + [['+/-', true], [' PAGE', false]] : HINT + [['←', true], [' BACK', false]]

        def draw(canvas)
          Layout.band(canvas, @title, [@items.size, page_mark].reject { |s| s.to_s.empty? }.join('  '), @color)
          return canvas.text(Layout.row(2), 1, @empty, Canvas::YELLOW) if @items.empty?

          on_page.each_with_index { |entry, slot| row(canvas, Layout.row(2 + slot), entry, slot) }
          top = Layout.row(3 + PER_PAGE)
          Layout.rule(canvas, top)
          Array(selected&.about).first(4).each_with_index do |line, i|
            canvas.text(top + 1 + i, 1, Layout.plain(line)[0, 28], i.zero? ? Canvas::WHITE : Canvas::LIGHT_GREY)
          end
        end

        private

        def row(canvas, row, entry, slot)
          number = format('%02d', ((@page * PER_PAGE) + slot + 1) % 100)
          count  = entry.count.to_s
          name   = Layout.plain(entry.name)[0, Layout::WIDTH - 6 - count.length - 2]
          leader = " #{'.' * [Layout::WIDTH - 4 - name.length - count.length - 2, 0].max} "
          if slot == @index
            canvas.text(row, 0, "#{number} #{name}#{leader}#{count}".ljust(Layout::WIDTH), Canvas::CYAN, rvs: true)
          else
            Layout.runs(canvas, row, 0, [[number, Canvas::YELLOW], [' ', nil], [name, Canvas::WHITE],
                                         [leader, Canvas::DARK_GREY], [count, Canvas::CYAN]])
          end
        end
      end
    end
  end
end
