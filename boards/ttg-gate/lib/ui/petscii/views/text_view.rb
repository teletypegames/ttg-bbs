# frozen_string_literal: true

require_relative 'picker'

module UI
  module Petscii
    module Views
      # A page of text in the content area: the help, a message, or a question
      # before a dial (BBS::Kit::Petscii::TextView, with the gate's hint
      # bar).
      class TextView < BBS::Kit::Petscii::TextView
        # The keys on the hint bar by default: back, and the two tabs.
        HINT = [['←', true], [' Back  ', false], ['O', true], [' Own  ', false], ['D', true], [' Discover', false]].freeze

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
