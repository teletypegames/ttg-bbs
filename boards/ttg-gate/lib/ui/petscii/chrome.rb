# frozen_string_literal: true

require_relative 'layout'

module UI
  module Petscii
    # The frame around every screen of the C64 face: the header (the colour
    # logo, the node and the clock), the raster stripe, the divider, the
    # sidebar and the hint bar. The sidebar is a cursor menu: Item is one of
    # its places, each with a hotkey that works from anywhere.
    module Chrome
      LOGO = [['T', Canvas::RED], ['T', Canvas::ORANGE], ['G', Canvas::YELLOW], [' ', nil],
              ['G', Canvas::LIGHT_GREEN], ['A', Canvas::CYAN], ['T', Canvas::LIGHT_BLUE], ['E', Canvas::PURPLE]].freeze
      RASTER = [Canvas::RED, Canvas::ORANGE, Canvas::YELLOW, Canvas::LIGHT_GREEN, Canvas::GREEN, Canvas::CYAN,
                Canvas::LIGHT_BLUE, Canvas::BLUE, Canvas::PURPLE, Canvas::LIGHT_RED].freeze
      # The tee and the corner of the Browse tree: both character sets have
      # them, the Canvas glyph table does not.
      TEE    = 0xab
      CORNER = 0xad

      # A place of the sidebar: +key+ the section it opens, +label+, the
      # index of its +hotkey+ letter in the label, the tree +branch+ before
      # it (nil, :tee or :corner), and whether it is +strong+ (white).
      Item = Data.define(:key, :label, :hotkey, :branch, :strong) do
        def letter = label[hotkey].downcase
      end

      # The sidebar from the top, a line each: an Item, :rule, :blank, or a
      # line of the counter.
      LINES = [
        Item.new(:own, 'Own', 0, nil, true), Item.new(:discover, 'Discover', 0, nil, true), :rule,
        Item.new(:search, 'Search', 0, nil, false), Item.new(:browse, 'Browse', 0, nil, false),
        Item.new(:software, 'Software', 4, :tee, false), Item.new(:country, 'Country', 0, :tee, false),
        Item.new(:network, 'Network', 6, :corner, false), Item.new(:new, 'New', 0, nil, false),
        Item.new(:random, 'Random', 0, nil, false), Item.new(:died, 'Died', 2, nil, false),
        Item.new(:graves, 'Graves', 0, nil, false), Item.new(:sources, 'Sources', 2, nil, false), :rule, :blank,
        :total, :boards, :online, :c64, :blank, Item.new(:help, 'Help', 0, nil, false),
        Item.new(:quit, 'Quit', 0, nil, false)
      ].freeze
      ITEMS   = LINES.grep(Item).freeze
      HOTKEYS = ITEMS.to_h { |i| [i.letter, i.key] }.freeze

      module_function

      # The header: the logo, the node and the clock, and the raster stripe.
      def header(canvas, node:, time:)
        LOGO.each_with_index do |(ch, color), i|
          canvas.text(0, 1 + i, ch, color, rvs: true) if color
        end
        canvas.text(0, 9, ' BBS', Canvas::WHITE)
        clock(canvas, node: node, time: time)
        Canvas::COLS.times { |col| canvas.text(1, col, '▀', RASTER[(col / 4) % RASTER.size]) }
      end

      def clock(canvas, node:, time:)
        node = "Node #{node}"
        canvas.text(0, 33 - node.length, node, Canvas::GREY)
        canvas.text(0, 34, time.strftime('%H:%M'), Canvas::CYAN)
      end

      def divider(canvas) = Layout::ROWS.times { |i| canvas.text(Layout.row(i), Layout::DIVIDER, '│', Canvas::DARK_GREY) }

      # The sidebar with +lit+ (an Item's key) as the cyan bar, and the
      # counter of +stats+ (BrowseService#stats, nil without a catalog).
      def sidebar(canvas, lit:, stats:)
        LINES.each_with_index do |line, i|
          row = Layout.row(i)
          case line
          when Item then item(canvas, row, line, line.key == lit)
          when :rule then canvas.text(row, Layout::SIDE, " #{'─' * (Layout::SIDE_WIDTH - 1)}", Canvas::DARK_GREY)
          when :blank then nil
          else counter(canvas, row, line, stats)
          end
        end
      end

      def item(canvas, row, item, lit)
        col = Layout::SIDE + 1
        if lit
          canvas.text(row, Layout::SIDE, ' ' * Layout::SIDE_WIDTH, Canvas::CYAN, rvs: true)
          canvas.text(row, col, item.label, Canvas::CYAN, rvs: true)
        else
          canvas.text(row, col, item.label, item.strong ? Canvas::WHITE : Canvas::LIGHT_GREY)
          canvas.text(row, col + item.hotkey, item.label[item.hotkey], Canvas::YELLOW)
        end
        return unless item.branch

        canvas.put(row, Layout::SIDE, item.branch == :tee ? TEE : CORNER, lit ? Canvas::CYAN : Canvas::DARK_GREY, rvs: lit)
      end

      def counter(canvas, row, line, stats)
        col = Layout::SIDE + 1
        value = ->(key) { stats ? stats[key].to_s : '-' }
        case line
        when :total then canvas.text(row, col, value.call(:boards), Canvas::WHITE)
        when :boards then canvas.text(row, col, 'boards', Canvas::GREY)
        when :online
          canvas.text(row, col, '▌', Canvas::LIGHT_GREEN)
          canvas.text(row, col + 2, value.call(:online), Canvas::WHITE)
        when :c64
          canvas.text(row, col, 'C64', Canvas::CYAN)
          canvas.text(row, col + 4, value.call(:petscii), Canvas::WHITE)
        end
      end

      # The hint bar: +parts+ of [text, key?], the keys yellow, the words
      # white.
      def hint(canvas, parts)
        Layout.runs(canvas, Layout::HINT_ROW, 1, parts.map { |t, k| [t, k ? Canvas::YELLOW : Canvas::WHITE] },
                    limit: Layout::HINT_WIDTH)
      end
    end
  end
end
