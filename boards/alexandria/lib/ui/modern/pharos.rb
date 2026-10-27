# frozen_string_literal: true

module UI
  module Modern
    # The desktop's title: the Pharos of Alexandria by the sea, its light
    # turning a quarter at every tick, and the board's name beside it. On a
    # screen too narrow for both only the name is left.
    class Pharos < BBS::Widget
      HEIGHT = 7

      TOWER = ['▄▀▄', '▐☼▌', '▄███▄', '▐█▀█▌', '▄█████▄', '▄██▀▀▀██▄'].freeze
      TOWER_WIDTH = 27

      FONT = {
        'A' => ['▄▀▀▄', '█▄▄█', '▀  ▀'], 'L' => ['█   ', '█   ', '▀▀▀▀'], 'E' => ['█▀▀▀', '█▀▀ ', '▀▀▀▀'],
        'X' => ['▀▄▄▀', '▄▀▀▄', '▀  ▀'], 'N' => ['█▄ █', '█ ▀█', '▀  ▀'], 'D' => ['█▀▀▄', '█  █', '▀▀▀ '],
        'R' => ['█▀▀▄', '█▀█ ', '▀  ▀'], 'I' => ['█', '█', '▀']
      }.freeze
      NAME = 3.times.map { |row| 'ALEXANDRIA'.chars.map { |c| FONT[c][row] }.join(' ') }.freeze
      TAGLINE = 'Wikipedia on a telnet line'
      FULL_WIDTH = TOWER_WIDTH + 2 + NAME.first.length

      # The light seen from the shore: to the left, at us, to the right, away.
      BEAMS = [['░░▒▒▒▓▓▓███', ''], ['▒▓█', '█▓▒'], ['', '███▓▓▓▒▒▒░░'], ['', '']].freeze
      WAVES = '▄▀▀▄▄▄▀▄▄▀▀▀▄▄▀▄'

      STONE = "\e[0;37m"
      LIGHT = "\e[1;33m"
      GLOW  = "\e[0;33m"
      SEA   = "\e[0;34m"
      FOAM  = "\e[1;34m"

      def initialize(**kw)
        super
        @frame = 0
      end

      def tick = (@frame += 1)

      def width = bounds.width >= FULL_WIDTH ? FULL_WIDTH : NAME.first.length

      def render(frame)
        tower = width > NAME.first.length
        x = bounds.x + ([bounds.width - width, 0].max / 2)
        name_x = tower ? x + TOWER_WIDTH + 2 : x
        if tower
          TOWER.each_with_index { |t, i| draw(frame, x, bounds.y + i, i == 1 ? lamp : "#{STONE}#{t.center(TOWER_WIDTH)}") }
          draw(frame, x, bounds.y + 6, sea)
        end
        NAME.each_with_index { |l, i| draw(frame, name_x, bounds.y + 2 + i, l, style(:accent)) }
        draw(frame, name_x + ((NAME.first.length - TAGLINE.length) / 2), bounds.y + 5, TAGLINE, style(:text_bright))
      end

      private

      def draw(frame, x, y, text, sgr = nil)
        frame.move(x, y)
        frame.write_ansi(text, base_sgr: sgr)
      end

      def lamp
        left, right = BEAMS[@frame % BEAMS.size]
        flame = left.empty? && right.empty? ? GLOW : LIGHT
        "#{beam(left.rjust(12))}#{STONE}▐#{flame}☼#{STONE}▌#{beam(right.ljust(12))}"
      end

      def beam(text) = text.gsub(/[░▒]+/) { "#{GLOW}#{_1}" }.gsub(/[▓█]+/) { "#{LIGHT}#{_1}" }

      def sea
        waves = (WAVES * ((width / WAVES.length) + 2))[@frame % WAVES.length, width]
        waves.chars.each_slice(4).map.with_index { |s, i| "#{i.even? ? SEA : FOAM}#{s.join}" }.join
      end
    end
  end
end
