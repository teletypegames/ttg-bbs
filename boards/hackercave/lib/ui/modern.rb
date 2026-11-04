# frozen_string_literal: true

require_relative 'logo'
require_relative 'modern/library'
require_relative 'modern/rfc_card'
require_relative 'modern/jargon'
require_relative 'modern/shelves_window'
require_relative 'modern/rfcs_window'
require_relative 'modern/reader_window'
require_relative 'modern/contents_window'
require_relative 'modern/text_window'
require_relative 'modern/jargon_windows'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): a desktop
  # under a menubar, the shelves and their RFCs in two-pane windows with an
  # RFC's record on the right, a search box, an RFC's links, and a reader
  # window that shows the RFC as it was published.
  module Modern
    ABOUT = 'HackerCave BBS — the hacker\'s reading room of Teletype Games, powered by rubbs. Every RFC, the ' \
            'documents the Internet is made of, from RFC 1 of 1969 to the newest, as the RFC Editor published ' \
            'them (rfc-editor.org). The index is refreshed every day; an RFC is fetched the first time someone ' \
            'reads it and kept for the next reader. The RFCs are the work of the IETF and their authors; ' \
            'copyright the IETF Trust and the authors.'
    READING = 'Pick an RFC and press Enter: it opens as it was published, 72 columns, page by page. PgUp/PgDn ' \
              'and the arrows scroll, Home/End go to the ends. The line under the text says the page of the RFC. ' \
              'Alt-O lists its headings to jump to, Alt-R the RFCs it names; Alt-E in a list shows the errata. ' \
              'Alt-L in a list shows the RFCs an RFC obsoletes or updates, and the ones that replaced it. ' \
              'F5 gives the reader the whole screen.'
    SEARCH = 'F3 searches by number (854, rfc 2119, ien 137), by series (std 7, bcp 14, fyi 1), or by words of the ' \
             'title, the authors, the keywords and the abstract (telnet window). status:standard (proposed, draft, ' \
             'bcp, info, experimental, historic) and year:1983 narrow it. F9 searches the full text of every RFC, ' \
             'mirrored from the RFC Editor and indexed every day.'
    JARGON_FILE = 'The Jargon File 4.4.7 (29 Dec 2003), the lexicon of hacker slang, public domain: its entries by ' \
                  'letter, a search, the word of the day, a random entry, and the introduction, Hacker Folklore and ' \
                  'the portrait of J. Random Hacker to read. Alt-L in an entry lists the entries it links to.'
    KEYS = ['Enter        read the RFC or the entry picked',
            'Alt+letter   a button of the window'].freeze
    TAGLINE = '─── the hacker\'s reading room · every RFC, as it was published ───'

    APP = BBS::Application.define do
      theme :synchronet
      helpers { include Library, RfcCard, Jargon }

      command(:classics, '&Classics', key: 'F2') { classics }
      command(:telnet, '&Telnet') { telnet }
      command(:search, '&Search…', key: 'F3') { search }
      command(:search_text, 'Search te&xt…', key: 'F9', hint: false) { search_text }
      command(:shelves, 'S&helves', key: 'F4') { shelf_list }
      command(:this_month, 'This m&onth') { this_month }
      command(:iens, '&IENs') { iens }
      command(:most_read, '&Most read', key: 'F7') { most_read }
      command(:newest, '&Newest', key: 'F8', hint: false) { newest }
      menu 'RFC', :classics, :telnet, :search, :search_text, :shelves, :this_month, :iens, :most_read, :newest,
           :separator, :log_off
      menu 'Jargon' do
        item('&Word of the day') { jargon_today }
        item('&Lexicon A-Z') { jargon_letters }
        item('&Search the lexicon…') { jargon_search }
        item('&Random entry') { jargon_random }
        item('&Folklore and chapters') { jargon_chapters }
      end
      help({ 'Reading' => READING, 'Search' => SEARCH, 'Jargon File' => JARGON_FILE }, about: ABOUT, keys: KEYS)

      status { index_status }

      desktop do
        art  Logo.half_blocks, top: 0
        line TAGLINE, bottom: 1
        on_show { classics }
      end

      parts ShelvesWindow, RfcsWindow, ReaderWindow, ContentsWindow, TextWindow, JargonWindows
    end
  end
end
