# frozen_string_literal: true

require_relative 'logo'
require_relative 'modern/library'
require_relative 'modern/book_card'
require_relative 'modern/chapters'
require_relative 'modern/shelves_window'
require_relative 'modern/books_window'
require_relative 'modern/chapters_window'
require_relative 'modern/reader_window'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): the logo
  # on the desktop, the shelves and their books in two-pane windows with a
  # book's record on the right, a search box, a book's chapters with the
  # start of the one picked, and a reader window.
  module Modern
    ABOUT = 'Scriptorium BBS — the classic literature vault of Teletype Games, powered by rubbs. ' \
            'Tens of thousands of books from Project Gutenberg (gutenberg.org), cut into chapters for your ' \
            'terminal. The texts are public domain in the USA; check the laws of your country before you ' \
            'pass them on. Thanks to Project Gutenberg and its volunteers, who made them.'
    READING = 'Pick a book and press Enter: the board fetches its text from Project Gutenberg once, cuts it into ' \
              'chapters, and keeps it for the next reader. In the reader: PgUp/PgDn and the arrows scroll, Home/End ' \
              'go to the ends of the chapter, ← and → (or P and N) turn to the previous and the next chapter. ' \
              'F5 gives the reader the whole screen.'
    KEYS    = ['← →          the previous / next chapter in the reader'].freeze
    TAGLINE = '─── the classic literature vault · books from Project Gutenberg ───'

    APP = Rubbs::Modern::Application.define do
      theme :synchronet
      helpers { include Library, BookCard, Chapters }

      command(:classics,  'Classics',    key: 'F2') { classics }
      command(:search,    'Search…',     key: 'F3') { search }
      command(:shelves,   'Bookshelves', key: 'F4', hint: 'Shelves') { shelf_list }
      command(:most_read, 'Most read',   key: 'F7') { most_read }
      menu 'Library', :classics, :search, :shelves, :most_read, :separator, :log_off
      help about: ABOUT, reading: READING, keys: KEYS

      status { library.ready? ? "#{thousands(library.count)} books" : 'preparing the catalog…' }

      desktop do
        art  Logo.half_blocks, top: 0
        line TAGLINE, bottom: 1
        on_show { classics }
      end

      parts ShelvesWindow, BooksWindow, ChaptersWindow, ReaderWindow
    end
  end
end
