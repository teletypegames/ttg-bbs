# frozen_string_literal: true

module UI
  class Petscii < Rubbs::Petscii::Face
    # A PETSCII work on the C64's own screen (a Rubbs::Petscii::Canvas in the
    # work's character set): every screen code, colour and reverse as it was
    # painted. The last cell of the screen stays empty (printing there
    # scrolls a C64), and the border and background colours cannot be set
    # over a telnet line: no terminal has a code for them.
    #
    # On a black background (the terminal's own) that is the picture exactly.
    # On another one a cell is drawn the closest way a black screen allows:
    # a space, or a character in the background colour, is a reversed space
    # in it; a character in black is the character reversed in the background
    # colour (exact); another ink keeps the background around a black
    # character; a reversed character keeps its ink around a black one.
    module WorkScreen
      C = Rubbs::Petscii::Canvas
      SPACE = 0x20

      # The bytes of +work+'s screen: the character set, the cells, the cursor
      # parked in the last cell.
      def self.bytes(work)
        canvas = C.new(charset: work.charset)
        PetsciiModel::ROWS.times do |y|
          PetsciiModel::COLS.times do |x|
            code, rvs, color = cell(*work.at(x, y), work.background)
            canvas.put(y, x, code, ink(color), rvs: rvs)
          end
        end
        canvas.frame + canvas.cursor(C::ROWS - 1, C::COLS - 1)
      end

      # The cell of screen code +code+ in +color+ on +background+ as a black
      # C64 screen draws it: [PETSCII code, reversed, colour].
      def self.cell(code, color, background)
        rvs     = code >= PetsciiModel::REVERSE
        petscii = PetsciiModel.petscii(code)
        return [petscii, rvs, color] if background.zero?

        blank = PetsciiModel::SPACES.include?(code & 0x7f)
        return [SPACE, true, background] if color == background || (blank && !rvs)
        return [SPACE, true, color] if blank

        rvs ? [petscii, true, color] : [petscii, true, background]
      end

      # The PETSCII colour code of the C64 colour +index+.
      def self.ink(index) = C.color(ColorModel[index].name)
    end
  end
end
