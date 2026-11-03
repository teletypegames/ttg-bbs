# frozen_string_literal: true

module UI
  class Petscii < BBS::Petscii::Face
    # Draws cells on a C64: a character, one of the sixteen colours and
    # reverse video, written as the C64's own colour and RVS control codes
    # (sent as they are through the PETSCII line) and the Unicode glyphs
    # rubbs turns into PETSCII. It sends a code only when the colour or the
    # reverse state changes.
    #
    # A C64 cell has one colour on the black screen: ink on black, or black
    # on ink (reverse). The canvas keeps to that, so it shows 1:1. An ANSI
    # piece has two colours a cell; Pen.art picks the one that matters more.
    class Pen
      P = BBS::Petscii
      # The control code of each C64 colour, by its index (ColorModel).
      CODES = [P::BLACK, P::WHITE, P::RED, P::CYAN, P::PURPLE, P::GREEN, P::BLUE, P::YELLOW, P::ORANGE, P::BROWN,
               P::LIGHT_RED, P::DARK_GREY, P::GREY, P::LIGHT_GREEN, P::LIGHT_BLUE, P::LIGHT_GREY].freeze
      # The C64 colour nearest to each CGA colour (0 black … 15 white).
      FROM_CGA = [0, 2, 5, 9, 6, 4, 3, 15, 11, 10, 13, 7, 14, 4, 3, 1].freeze
      # How bright each CGA colour looks, to choose between two in a cell.
      CGA_LIGHT = [0, 3, 5, 4, 1, 3, 6, 8, 4, 7, 10, 12, 6, 8, 11, 15].freeze
      # CP437 drawing characters the C64 has no glyph for, as the nearest
      # single-line one.
      CP437 = {
        '╡' => '┤', '╢' => '┤', '╖' => '┐', '╕' => '┐', '╜' => '┘', '╛' => '┘', '╞' => '├', '╟' => '├',
        '╧' => '┴', '╨' => '┴', '╤' => '┬', '╥' => '┬', '╙' => '└', '╘' => '└', '╒' => '┌', '╓' => '┌',
        '╫' => '┼', '╪' => '┼', '▬' => '▄', '∙' => '.', '·' => '.', '■' => '▄', '¡' => '!', '¿' => '?',
        '°' => 'o', '≡' => '=', '±' => '+', '÷' => '/', '√' => 'v', 'ⁿ' => 'n', '²' => '2',
        'ß' => 'b', '¬' => '-', '⌐' => '-', '«' => '<', '»' => '>', '♦' => '*', '•' => '.', '►' => '>',
        '◄' => '<', '▲' => '↑', '▼' => 'v', '→' => '>', '↓' => 'v', '♥' => '*',
        '☺' => '@', '☻' => '@', '♣' => '*', '♠' => '*', '○' => 'o', '◘' => '█', '◙' => 'o', '⌂' => '^'
      }.freeze
      HALVES = %w[▀ ▄ ▌ ▐].freeze
      SHADES = %w[░ ▒ ▓].freeze

      def initialize
        reset
      end

      # Forgets the state: the next cell sends its colour and reverse state.
      def reset
        @color = nil
        @rvs   = nil
      end

      # The C64 cleared reverse video (a RETURN does).
      def rvs_off! = (@rvs = false)

      # The bytes for a cell: +char+ (a Unicode character the PETSCII line
      # shows in one cell), +color+ (a C64 colour index, or nil when the cell
      # shows no ink) and +rvs+.
      def cell(char, color, rvs)
        out = +''
        if rvs != @rvs
          out << (rvs ? P::RVS_ON : P::RVS_OFF)
          @rvs = rvs
        end
        if color && color != @color
          out << CODES[color]
          @color = color
        end
        out << char
      end

      # The bytes for one screen row of +cells+ ([char, colour, rvs], +width+
      # of them): the cells up to the last that shows, then a RETURN unless
      # the row is full (the cursor wraps by itself then).
      def row(cells, width)
        last = cells.rindex { |ch, _, rvs| ch != ' ' || rvs }
        out = +''
        cells[0..last].each { |c| out << cell(*c) } if last
        return out if last == width - 1

        rvs_off!
        out << "\r\n"
      end

      # +text+ in the C64 colour +color+, not reversed.
      def text(text, color) = cell('', color, false) + text

      # A canvas cell [char, fg, bg] as the C64 shows it: [char, colour, rvs].
      # █, ▀ and ▐ are a reversed space, ▄ and ▌.
      def self.canvas(char, fg, bg)
        if bg.zero?
          return [' ', nil, false] if char == ' ' || fg.zero?

          case char
          when '█' then [' ', fg, true]
          when '▀' then ['▄', fg, true]
          when '▐' then ['▌', fg, true]
          else [char, fg, false]
          end
        else
          case char
          when '█' then [' ', nil, false]
          when '▀' then ['▄', bg, false]
          when '▐' then ['▌', bg, false]
          else [char, bg, true]
          end
        end
      end

      # A cell of an ANSI piece [char, fg, bg] (CGA colours) as a C64 cell.
      # On a black background it is the character in its colour; on another
      # one a space or text is reversed in the background colour, a full
      # block is the foreground, and a half block or a shade keeps the
      # colour that looks brighter.
      def self.art(char, fg, bg)
        char = CP437.fetch(char, char)
        return [' ', nil, false] if bg.zero? && (char == ' ' || fg.zero?)
        return [' ', FROM_CGA[bg], true] if char == ' ' || fg == bg
        return [' ', FROM_CGA[fg], true] if char == '█'
        return on_black(char, fg) if bg.zero?
        return two_tone(char, fg, bg) if HALVES.include?(char) || SHADES.include?(char)

        [BBS::Petscii.cell(char), FROM_CGA[bg], true]
      end

      # A character on a black background: in its colour, a shade as ▒.
      def self.on_black(char, fg)
        return shade(char, fg) if SHADES.include?(char)

        canvas(HALVES.include?(char) ? char : BBS::Petscii.cell(char), FROM_CGA[fg], 0)
      end

      def self.shade(char, fg) = char == '▓' ? [' ', FROM_CGA[fg], true] : ['▒', FROM_CGA[fg], false]

      # A half block or shade on a coloured background: the brighter of the
      # two colours stays.
      def self.two_tone(char, fg, bg)
        keep_fg = !fg.zero? && CGA_LIGHT[fg] >= CGA_LIGHT[bg]
        return ['▒', FROM_CGA[keep_fg ? fg : bg], false] if SHADES.include?(char)

        color = FROM_CGA[keep_fg ? fg : bg]
        cell = keep_fg ? [char, color, 0] : [opposite(char), color, 0]
        canvas(*cell)
      end

      def self.opposite(char) = { '▀' => '▄', '▄' => '▀', '▌' => '▐', '▐' => '▌' }.fetch(char, char)
    end
  end
end
