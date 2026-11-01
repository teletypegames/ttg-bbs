# frozen_string_literal: true

require_relative 'picker'

module UI
  module Petscii
    module Views
      # A page of text in the main area: the help, a message, or a question
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

        def hint = @hint || [['←', true], [' BACK  ', false], ['O', true], [' OWN  ', false], ['D', true], [' DISCOVER', false]]

        def draw(canvas)
          Layout.band(canvas, @title, '', @color)
          @lines.first(Layout::ROWS - 4).each_with_index do |line, i|
            text, color = line.is_a?(String) ? [line, Canvas::LIGHT_GREY] : line
            canvas.text(Layout.row(2 + i), 1, Layout.plain(text)[0, Layout::WIDTH - 2], color)
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
            ['THE SIDEBAR', Canvas::WHITE], 'CRSR LEFT: TO THE SIDEBAR', 'CRSR RIGHT: TO THE LIST',
            'CRSR UP, DOWN: MOVE', 'RETURN: OPEN IT', 'A YELLOW LETTER OPENS ITS', 'PLACE FROM ANYWHERE.', '',
            ['THE LISTS', Canvas::WHITE], '1-9, 0: THAT ROW  +/-: PAGE', 'F: STATE FILTER  /: SEARCH',
            '←, RUN/STOP: BACK', '',
            ['A BOARD', Canvas::WHITE], 'RETURN: DIAL  B: ITS BANNER', 'WHEN IT HANGS UP, YOU ARE', 'BACK WHERE YOU WERE.'
          ]
          new('HELP', lines, color: Canvas::LIGHT_GREY, section: :help)
        end
      end
    end
  end
end
