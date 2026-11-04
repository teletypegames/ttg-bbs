# frozen_string_literal: true

require_relative 'logo'
require_relative 'wording'
require_relative 'modern/art_lines'
require_relative 'modern/viewer'
require_relative 'modern/canvas_widget'
require_relative 'modern/helpers'
require_relative 'modern/years_window'
require_relative 'modern/packs_window'
require_relative 'modern/files_window'
require_relative 'modern/wall_window'
require_relative 'modern/save_window'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): a desktop
  # under a menubar; the 16colo.rs gallery as years, packs and files in
  # two-pane windows and a piece on the whole screen; the shared canvas in a
  # window of its own; the Wall with a preview of every work.
  module Modern
    ABOUT = 'Pixelia BBS — the PETSCII & ANSI art gallery of Teletype Games, powered by rubbs. The gallery is ' \
            'the 16colo.rs archive of the ANSI scene, read live from its public API. The canvas is one 40×25 ' \
            'picture that every caller paints on, from a Commodore 64 or from here, and both see it the same. ' \
            'Saved pictures go on the Wall.'
    CANVAS_KEYS = 'Arrows move · type to paint · Enter paints the brush · Backspace/Delete rub out · F7/F8 ink · ' \
                  'F9 or Ctrl-R reverse (black on the ink: a space is a block of colour) · Insert or Ctrl-G glyph ' \
                  'mode: the letters paint graphics (q w e / a s d / z x c are box corners, g █ t ▀ b ▄ y ▌ h ▐ u ▒) · ' \
                  'Ctrl-S save to the Wall · Ctrl-Z undo · mouse: click to place, drag or right click to paint, ' \
                  'click an ink or a brush in the panel. 20 cells a second at most.'
    TAGLINE = 'The PETSCII & ANSI art gallery'

    # PIXELIA in half blocks, each letter in its colour on black.
    LOGO = Logo.half_blocks.map do |runs|
      runs.map { |text, color| "\e[0;38;5;#{ColorModel[color || 0].xterm};40m#{text}" }.join
    end.freeze

    APP = BBS::Application.define do
      theme :synchronet
      helpers { include Helpers }

      command(:gallery, '&16colo.rs years', key: 'F2', hint: 'Gallery') { open_years }
      command(:canvas, '&Open the canvas', key: 'F3', hint: 'Canvas') { open_canvas }
      command(:save, '&Save to the Wall', key: 'Ctrl-S', hint: false) { save_to_wall }
      command(:wall, '&Show the Wall', key: 'F4', hint: 'Wall') { open_wall }
      menu 'Gallery', :gallery, :separator, :log_off
      menu 'Canvas', :canvas, :save
      menu 'Wall', :wall
      help about: ABOUT, canvas_keys: CANVAS_KEYS

      status { "#{canvas.painters} painting" }

      desktop do
        art  LOGO, top: 2
        line TAGLINE, top: 6, style: :text_bright
        line 'F2  the ANSI gallery of 16colo.rs', top: 9, style: :text
        line 'F3  the canvas everyone paints on ', top: 10, style: :text
        line 'F4  the Wall of saved pictures   ', top: 11, style: :text
        line '─── classic 8-bit art and a canvas for your terminal or Commodore 64 ───', bottom: 0
      end

      parts YearsWindow, PacksWindow, FilesWindow, WallWindow, SaveWindow
    end
  end
end
