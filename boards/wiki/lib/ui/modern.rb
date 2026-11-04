# frozen_string_literal: true

require_relative 'wording'
require_relative 'modern/helpers'
require_relative 'modern/browser_window'

module UI
  # The wiki on an ANSI terminal: a Norton Commander-style two-pane browser
  # that fills the screen between the menubar and the statusbar — page tree
  # on the left (indented by route depth), the selected page rendered as
  # ANSI markdown on the right. F5 / Alt-Enter (the window's zoom) puts it
  # back into a window and out again.
  module Modern
    ABOUT = 'TTG Wiki BBS — the Teletype Games wiki over telnet, from Teletype Games, powered by rubbs and Grav. ' \
            'Pick a page on the left, read it on the right. Pages marked * are private: ' \
            'Wiki > Log in with a Teletype Games account of the wiki-supervisor role reads them.'
    KEYS  = ['Up/Down      pick a page', 'Tab          focus the reader', 'PgUp/PgDn    scroll',
             '*            supervisor only'].freeze

    APP = BBS::Application.define do
      theme :nortoncommander
      helpers { include Helpers }

      command(:browse,  '&Browse pages',  key: 'F2', hint: 'Browse')  { open_browser }
      command(:qr,      'Page &QR code',  key: 'F3', hint: 'QR')      { show_qr }
      command(:refresh, '&Refresh index', key: 'F8', hint: 'Refresh') { refresh_pages }
      menu 'Wiki', :log_in, :log_out, :separator, :browse, :qr, :refresh, :separator, :log_off
      help about: -> { "#{ABOUT}\n\nSource: #{wiki.base_url}\nPages:  #{wiki.pages.size}" }, keys: KEYS

      status { "#{'supervisor  ' if supervisor?}#{wiki.pages.size} pages" }
      init { @who = who }
      on_tick { follow_identity }

      desktop { on_show { open_browser } }

      parts BrowserWindow
    end
  end
end
