# frozen_string_literal: true

require_relative 'wording'
require_relative 'modern/helpers'
require_relative 'modern/directories_window'
require_relative 'modern/titles_window'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): the directories
  # in a two-pane window, a directory's titles with the one picked on the right,
  # its download by ZMODEM, XMODEM-1K or XMODEM, and the network's feedback
  # and wall (ttg-common).
  module Modern
    ABOUT = 'WarpEngine BBS — the file area of Teletype Games on a telnet line, powered by rubbs. ' \
            'The directories are the folders the WarpEngine of teletypegames.org keeps for machines without ' \
            'a web browser: pick one, pick a title, and take it home by ZMODEM or XMODEM.'
    DOWNLOADS = 'ZMODEM (Enter or Z): SyncTERM, NetRunner, Qodem and the web terminal start it by themselves. ' \
                'XMODEM-1K (K) and XMODEM (M): start the download in your terminal, name the file, and the board ' \
                'sends it; a Commodore terminal (CCGMS, Novaterm, UltimateTerm) takes these. Every file is checked ' \
                'against its directory before it goes.'
    TAGLINE = '─── the file area of Teletype Games ───'

    APP = Rubbs::Modern::Application.define do
      theme :synchronet
      helpers { include Helpers }

      command(:directories, 'Directories', key: 'F2') { show(:directories) }
      command(:wall,     'The engine room wall…', hint: 'Wall') { wall }
      command(:feedback, 'Write to the sysops…', hint: 'Feedback') { feedback }
      menu 'Files', :directories, :separator, :wall, :feedback, :separator, :log_off
      help about: ABOUT, downloads: DOWNLOADS, keys: ['Enter        on a title: ZMODEM']
      status { "#{catalog.directories.size} directories" }

      desktop do
        art Rubbs::Common::Text::BlockFont.half_blocks('WARP'), top: 0
        line TAGLINE, bottom: 0
        on_show { show(:directories) }
      end

      parts DirectoriesWindow, TitlesWindow
    end
  end
end
