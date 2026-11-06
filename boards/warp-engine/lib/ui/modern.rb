# frozen_string_literal: true

require_relative 'wording'
require_relative 'modern/helpers'
require_relative 'modern/shelves_window'
require_relative 'modern/titles_window'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): the shelves
  # in a two-pane window, a shelf's titles with the one picked on the right,
  # its download by ZMODEM, XMODEM-1K or XMODEM, and the network's feedback
  # and wall (ttg-common).
  module Modern
    ABOUT = 'WarpEngine BBS — the file area of Teletype Games on a telnet line, powered by rubbs. ' \
            'The shelves are the folders the WarpEngine of teletypegames.org keeps for machines without ' \
            'a web browser: pick one, pick a title, and take it home by ZMODEM or XMODEM.'
    DOWNLOADS = 'ZMODEM (Enter or Z): SyncTERM, NetRunner, Qodem and the web terminal start it by themselves. ' \
                'XMODEM-1K (K) and XMODEM (M): start the download in your terminal, name the file, and the board ' \
                'sends it; a Commodore terminal (CCGMS, Novaterm, UltimateTerm) takes these. Every file is checked ' \
                'against its shelf before it goes.'
    TAGLINE = '─── the file area of Teletype Games ───'

    APP = Rubbs::Modern::Application.define do
      theme :synchronet
      helpers { include Helpers }

      command(:shelves,  'Shelves', key: 'F2') { show(:shelves) }
      command(:wall,     'The engine room wall…', hint: 'Wall') { wall }
      command(:feedback, 'Write to the sysops…', hint: 'Feedback') { feedback }
      menu 'Files', :shelves, :separator, :wall, :feedback, :separator, :log_off
      help about: ABOUT, downloads: DOWNLOADS, keys: ['Enter        on a title: ZMODEM']
      status { "#{catalog.shelves.size} shelves" }

      desktop do
        art Rubbs::Common::Text::BlockFont.half_blocks('WARP'), top: 0
        line TAGLINE, bottom: 0
        on_show { show(:shelves) }
      end

      parts ShelvesWindow, TitlesWindow
    end
  end
end
