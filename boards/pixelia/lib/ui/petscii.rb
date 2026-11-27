# frozen_string_literal: true

require_relative 'logo'
require_relative 'glyph_keys'
require_relative 'wording'

require_relative 'petscii/pen'
require_relative 'petscii/canvas_view'
require_relative 'petscii/canvas'
require_relative 'petscii/gallery'
require_relative 'petscii/work_screen'
require_relative 'petscii/exhibition'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen. A cursor menu
  # under the masthead, the 16colo.rs gallery in numbered cursor lists and
  # pages of 40 columns, the shared canvas, which is the C64's own screen
  # size, and the Exhibition.
  class Petscii < Rubbs::Petscii::Face
    HELP = [
      " #{WH}Pixelia#{LG} is an art board of Teletype Games.", '',
      " #{YE}1#{LG} The ANSI gallery: the 16colo.rs archive, year by year, pack by pack. A piece shows 40 " \
      'columns at a time: R shows the next 40 columns of a wider one.', '',
      " #{YE}2#{LG} The canvas: one 40×25 picture that every caller paints on, from a C64 or a modern " \
      'terminal, and both see it the same.', '',
      " #{YE}3#{LG} The Exhibition: the pictures saved from the canvas, and the PETSCII pictures of TTG " \
      'Canvas 64 uploaded by XMODEM (U, after you log in).', '',
      " #{GR}Call Pixelia on a modern terminal for the full-colour gallery of 80 columns.#{LG}"
    ].freeze

    # PIXELIA in reversed blocks, five rows, a colour a letter.
    LOGO = Logo.rows.map do |runs|
      line = runs.map do |text, color|
        blocks = Rubbs::Common::Text::BlockFont.reversed(text)
        color ? "#{Pen::CODES[color]}#{blocks}" : blocks
      end
      "      #{line.join}#{LG}"
    end.freeze

    include Gallery
    include Exhibition

    sub_menu(:exhibition, title: 'THE EXHIBITION') do
      item('1', -> { "the works #{GR}#{exhibition.all.size}#{LG}" }, 'newest first') { exhibition_list }
      item('u', 'upload a picture', 'a ttg canvas 64 .tcv by xmodem') { exhibition_upload }
      back 'to the main menu'
    end

    masthead do
      gap
      rule
      gap
      art LOGO
      gap
      rule
      line ' the petscii & ansi art gallery', color: WH
      line ' classic 8-bit art and a canvas for all', color: GR
      rule
    end

    main_menu(home: :masthead) do
      item('1', "the ansi gallery #{GR}16colo.rs#{LG}", 'the 16colo.rs archive, year by year') { gallery_years }
      item('2', -> { "the canvas #{GR}#{canvas.painters} painting now#{LG}" }, 'one picture, every caller paints on it') do
        Canvas.new(self).run
      end
      item(
        '3',
        lambda {
          "the exhibition #{GR}#{exhibition.all.size} works#{LG}"
        },
        'the pictures saved and uploaded'
      ) { sub_menu(:exhibition) }
      item('w', 'the wall', 'talk about the art') { TTG::Wall.open(@session) }
      item('f', 'write to the sysops', 'a bug, an idea, a word') { TTG::Feedback.open(@session) }
      item('h', 'help', 'how the board works') { page('PIXELIA BBS', HELP) }
      log_off 'hang up. see you!'
    end
  end
end
