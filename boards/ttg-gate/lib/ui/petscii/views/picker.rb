# frozen_string_literal: true

require_relative '../layout'

module UI
  module Petscii
    module Views
      # A view in the main area of the C64 face: draws itself on a Canvas,
      # tells the hint bar its keys, and answers the keys that are its own
      # (#handle: :redraw, an action to call, or nil when the key is not its
      # own).
      class View
        def draw(canvas); end

        def hint = []

        def handle(_key) = nil

        # The place of the sidebar this view lights, nil for its section's.
        def section = nil
      end

      # A view with a list of items and a lit one, +per_page+ a page: CRSR
      # up and down move (past the edge of a page to the next one), + and -
      # turn the pages, a digit takes that place of the page (0 the tenth),
      # RETURN takes the lit one (#take).
      class Picker < View
        PAGES = { '+' => 1, '-' => -1 }.freeze

        attr_reader :items, :index, :page

        def initialize(items, per_page:)
          super()
          @items    = items
          @per_page = per_page
          @page     = 0
          @index    = 0
        end

        def pages = [(@items.size + @per_page - 1) / @per_page, 1].max

        def on_page = @items[@page * @per_page, @per_page] || []

        def selected = on_page[@index]

        def handle(key)
          case key
          when :up, :down then move(key == :up ? -1 : 1)
          when *PAGES.keys then turn(PAGES[key])
          when :enter then selected && take(selected)
          when /\A\d\z/
            slot = (key.to_i - 1) % 10
            return nil unless slot < @per_page
            return :redraw unless on_page[slot]

            @index = slot
            take(selected)
          end
        end

        # Moves the lit item +delta+ places, over the edge of the page.
        def move(delta)
          slot = @index + delta
          if slot.negative? && @page.positive?
            @page -= 1
            @index = on_page.size - 1
          elsif slot >= on_page.size && @page < pages - 1
            @page += 1
            @index = 0
          else
            @index = slot.clamp(0, [on_page.size - 1, 0].max)
          end
          :redraw
        end

        def turn(delta)
          target = (@page + delta).clamp(0, pages - 1)
          @index = 0 unless target == @page
          @page = target
          :redraw
        end

        # Keeps the place of the list when its items change: the same page
        # and place where they still exist.
        def replace(items)
          @items = items
          @page  = @page.clamp(0, pages - 1)
          @index = @index.clamp(0, [on_page.size - 1, 0].max)
        end

        def take(_item) = nil

        # "1/5" when there is more than one page.
        def page_mark = pages > 1 ? "#{@page + 1}/#{pages}" : ''
      end
    end
  end
end
