# frozen_string_literal: true

require_relative 'picker'

module UI
  module Petscii
    module Views
      # A page of text in the content area: the help, a message, or a question
      # before a dial. +lines+ are [text, colour] each (a String is light
      # grey); +keys+ the chips under them, [key, word] each.
      class TextView < View
        def initialize(title, lines, color:, section: nil, keys: [], hint: nil)
          super()
          @title   = title
          @lines   = lines
          @color   = color
          @section = section
          @keys    = keys
          @hint    = hint
        end

        attr_reader :section
        # The keys on the hint bar; Gate#pop_up sets "Press a key" for a view
        # shown over the current one.
        attr_writer :hint

        def hint = @hint || [['←', true], [' Back  ', false], ['O', true], [' Own  ', false], ['D', true], [' Discover', false]]

        def draw(canvas)
          Layout.band(canvas, @title, '', @color)
          @lines.first(Layout::ROWS - 3).each_with_index do |line, i|
            text, color = line.is_a?(String) ? [line, Canvas::LIGHT_GREY] : line
            canvas.text(Layout.row(2 + i), 1, Layout.plain(text)[0, Layout::EDGE - 1], color)
          end
          col = 1
          @keys.each do |key, word|
            col = Layout.chip(canvas, Layout.row(3 + @lines.size), col, key, Canvas::YELLOW)
            col = Layout.chip(canvas, Layout.row(3 + @lines.size), col, word, Canvas::ORANGE) + 2
          end
        end

        # The help: the keys of the C64 face.
        def self.help
          lines = [
            ['The tabs and the menu', Canvas::WHITE], 'O: Own  D, G: Discovery  P: Profile',
            'CRSR up at the top of a list: the menu,', 'again: the tabs  CRSR left, right: move',
            'RETURN: open  CRSR down: back', 'A yellow sign opens its place from',
            'anywhere: / Find, B Browse, N New,', 'R Random, S Sources;',
            'W Software, C Country, K Network.', '',
            ['The lists', Canvas::WHITE], '1-9, 0: that row  +/-: page', 'F: state filter  ←, RUN/STOP: back', '',
            ['A board', Canvas::WHITE], 'RETURN: dial  B: its banner', 'When it hangs up, you are back where',
            'you were.  Q: hang up'
          ]
          new('HELP', lines, color: Canvas::LIGHT_GREY, section: :help)
        end
      end
    end
  end
end
