# frozen_string_literal: true

module UI
  module Modern
    # The menubar, the status bar's hints and the desktop under them.
    module Menu
      ABOUT = 'Pixelia BBS — the PETSCII & ANSI art gallery of Teletype Games, powered by rubbs. The gallery is ' \
              'the 16colo.rs archive of the ANSI scene, read live from its public API. The canvas is one 40×25 ' \
              'picture that every caller paints on, from a Commodore 64 or from here, and both see it the same. ' \
              'Saved pictures go on the Wall.'
      KEYS = 'Arrows move · type to paint · Enter paints the brush · Backspace/Delete rub out · F7/F8 ink · ' \
             'F9 or Ctrl-R reverse (black on the ink: a space is a block of colour) · Insert or Ctrl-G glyph ' \
             'mode: the letters paint graphics (q w e / a s d / z x c are box corners, g █ t ▀ b ▄ y ▌ h ▐ u ▒) · ' \
             'Ctrl-S save to the Wall · Ctrl-Z undo · mouse: click to place, drag or right click to paint, ' \
             'click an ink or a brush in the panel. 20 cells a second at most.'

      module_function

      def install(app)
        app.menubar { Menu.menus(self) }
        hints(app)
        app.on_tick { statusbar.right_text = status_text }
        app.init { Menu.desktop(self) }
      end

      def menus(bar)
        bar.menu('&Gallery') do
          item('&16colo.rs years', shortcut: 'F2') { open_years }
          separator
          item('&Log off', shortcut: 'Alt-X') { :halt }
        end
        bar.menu('&Canvas') do
          item('&Open the canvas', shortcut: 'F3') { open_canvas }
          item('&Save to the Wall', shortcut: 'Ctrl-S') { save_to_wall }
        end
        bar.menu('&Wall') { item('&Show the Wall', shortcut: 'F4') { open_wall } }
        bar.menu('&Help') do
          item('&About') { BBS::Dialogs.message(self, ABOUT, title: ' About ', width: 64) }
          item('&Canvas keys') { BBS::Dialogs.message(self, KEYS, title: ' Canvas keys ', width: 64) }
        end
      end

      def hints(app)
        app.status_hint('F2',  'Gallery') { open_years }
        app.status_hint('F3',  'Canvas') { open_canvas }
        app.status_hint('F4',  'Wall') { open_wall }
        app.status_hint('F10', 'Menu') { menubar.open(0) }
        app.status_hint('Alt-X', 'Bye') { :halt }
      end

      def desktop(app)
        logo = app.add(LogoWidget.new)
        logo.layout(1, 3, app.cols, LogoWidget::HEIGHT)
        app.desktop_label('F2  the ANSI gallery of 16colo.rs', :text, 1, 10, app.cols, align: :center)
        app.desktop_label('F3  the canvas everyone paints on ', :text, 1, 11, app.cols, align: :center)
        app.desktop_label('F4  the Wall of saved pictures   ', :text, 1, 12, app.cols, align: :center)
        app.desktop_label('─── classic 8-bit art and a canvas for your terminal or Commodore 64 ───', :text_dim,
                          1, app.rows - 2, app.cols, align: :center)
        app.statusbar.right_text = app.status_text
      end
    end
  end
end
