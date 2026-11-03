# frozen_string_literal: true

require_relative '../layout'

module UI
  module Petscii
    module Views
      # A view in the content area of the C64 face: a page of the Gate that
      # draws itself on a Canvas, tells the hint bar its keys, and answers
      # the keys that are its own (the others go to the Gate's hotkeys).
      class View < BBS::Page
        def hint = []

        # The section this view belongs to (the place of the sub-menu it
        # lights), nil for the one it was opened in.
        def section = nil
      end

      # A view with a list of items and a lit one, +per_page+ a page: CRSR
      # up and down move (past the edge of a page to the next one), + and -
      # turn the pages, a digit takes that place of the page (0 the tenth),
      # RETURN takes the lit one (#take).
      class Picker < View
        key(:up) { move(-1) }
        key(:down) { move(1) }
        key('+') { turn(1) }
        key('-') { turn(-1) }
        key(:enter) { selected ? take(selected) : pass }
        key(/\A\d\z/) do |digit|
          slot = (digit.to_i - 1) % 10
          pass unless slot < @per_page
          next unless on_page[slot]

          @index = slot
          take(selected)
        end

        attr_reader :items, :index, :page

        def initialize(items, per_page:)
          super()
          @items    = items
          @per_page = per_page
          @page     = 0
          @index    = 0
        end

        def pages_count = [(@items.size + @per_page - 1) / @per_page, 1].max

        def on_page = @items[@page * @per_page, @per_page] || []

        def selected = on_page[@index]

        # Whether the first item of the first page is lit.
        def at_top? = @page.zero? && @index.zero?

        # Moves the lit item +delta+ places, over the edge of the page.
        def move(delta)
          slot = @index + delta
          if slot.negative? && @page.positive?
            @page -= 1
            @index = on_page.size - 1
          elsif slot >= on_page.size && @page < pages_count - 1
            @page += 1
            @index = 0
          else
            @index = slot.clamp(0, [on_page.size - 1, 0].max)
          end
        end

        def turn(delta)
          target = (@page + delta).clamp(0, pages_count - 1)
          @index = 0 unless target == @page
          @page = target
        end

        # Keeps the place of the list when its items change: the same page
        # and place where they still exist.
        def reload_items(items)
          @items = items
          @page  = @page.clamp(0, pages_count - 1)
          @index = @index.clamp(0, [on_page.size - 1, 0].max)
        end

        def take(_item) = nil

        # "1/5" when there is more than one page.
        def page_mark = pages_count > 1 ? "#{@page + 1}/#{pages_count}" : ''
      end
    end
  end
end
