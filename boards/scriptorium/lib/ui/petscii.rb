# frozen_string_literal: true

require_relative 'logo'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen. A cursor menu,
  # the shelves and the books as numbered lists, a book's record on a page,
  # its chapters as a numbered list, and the reader: 38-column pages that
  # wait for RETURN, N and P for the next and the previous chapter.
  class Petscii < BBS::Petscii::Face
    LOGO_COLORS = [WH, WH, YE, YE, CY].freeze
    PREPARING   = 'The catalog is being prepared: it is downloaded from Project Gutenberg and indexed. ' \
                  'Try again in a minute. The classics shelf is open meanwhile.'
    ABOUT = [
      " #{WH}scriptorium bbs#{LG}", '',
      ' The classic literature vault of Teletype Games: tens of thousands of books from Project Gutenberg, ' \
      'cut into chapters for your terminal.', '',
      ' Pick a book, and the board fetches its plain text from gutenberg.org once, cuts it into chapters and ' \
      'keeps it for the next reader.', '',
      ' The texts are public domain in the USA; check the laws of your country before you pass them on. ' \
      'Thanks to Project Gutenberg and its volunteers, who made them.', '',
      " #{GR}reader keys: return next page, b back a page, n / p next / previous chapter, q back.#{LG}"
    ].freeze

    title('SCRIPTORIUM BBS') { library.ready? ? "#{library.count} books" : '' }

    masthead do
      rule
      logo Logo::WORD, colors: LOGO_COLORS, glyphs: Logo::GLYPHS
      rule
      line 'the classic literature vault', color: WH
      line 'project gutenberg, chapter by chapter', color: GR
      rule
    end

    main_menu(above: -> { " #{GR}#{catalog_line}#{LG}" }) do
      item('1', 'the classics shelf', 'the great books, open at once') { classics }
      item('2', 'gutenberg bookshelves', 'the shelves of project gutenberg') { shelves }
      item('3', 'search by title or author', 'words, and lang:fr for one language') { search }
      item('4', 'most read on this board', 'what the callers here read') { most_read }
      item('a', 'about', 'the board, the books, the reader keys') { page('ABOUT', ABOUT) }
      log_off 'hang up. see you!'
    end

    private

    def catalog_line = library.ready? ? "#{library.count} books in the catalog" : 'the catalog is being prepared'

    def classics = books('CLASSICS', library.books_on(library.classics_shelf))

    def shelves
      return alert(PREPARING, color: YE) unless library.ready?

      list = library.shelves.drop(1)
      each_pick('BOOKSHELVES', list, right: "#{list.size} shelves",
                                     label: ->(s) { "#{s.label.downcase} #{GR}#{s.count}#{LG}" }) do |shelf|
        books(shelf.label.upcase, library.books_on(shelf))
      end
    end

    def search
      return alert(PREPARING, color: YE) unless library.ready?

      title('SEARCH')
      query = prompt('search', hint: 'Words of the title or the author. Add lang:fr (de, es, ...) for one language.',
                               max: 60)
      return unless query

      case (found = library.search(query))
      when :too_short then alert('A word of two letters or more, please.', color: YE)
      when [] then alert('Nothing found. Fewer or other words?', color: YE)
      else books("SEARCH: #{query.upcase}"[0, 28], found)
      end
    end

    def most_read
      list = library.most_read
      return alert('Nothing has been read here yet. Be the first!', color: YE) if list.empty?

      counts = list.to_h { |b, n| [b.id, n] }
      books('MOST READ HERE', list.map(&:first), label: ->(b) { "#{GR}#{counts[b.id]}#{LG} #{b.short_title}" })
    end

    def books(heading, list, label: :short_title)
      each_pick(heading, list, label: label, empty: 'no books here.', right: "#{list.size} books") { |book| info(book) }
    end

    def info(book)
      page("EBOOK ##{book.id}", record(book), wait: false)
      case actions(%w[r read], ['c', 'qr code'], %w[q back])
      when 'r' then open_book(book)
      when 'c' then show_qr(book)
      end
    end

    # The book's Project Gutenberg page as a QR code: a phone or an
    # e-reader takes the whole book from there.
    def show_qr(book)
      title("EBOOK ##{book.id}", 'scan me')
      pause if qr(book.link)
    end

    # A book's record: the title, the author, the facts, the subjects and
    # the credit.
    def record(book)
      subjects = plain(book.subject_list.first(3).join('; '))
      credit   = "ebook ##{book.id} from project gutenberg, #{book.url} - public domain in the usa."
      [*lines(plain(book.short_title), WH), *lines(plain("by #{book.author}"), CY),
       " #{GR}#{facts(book)}#{LG}", *(['', *lines(subjects)] unless subjects.empty?), '', *lines(credit, GR)]
    end

    # +text+ wrapped, each line indented and in +color+.
    def lines(text, color = nil)
      wrap(text).map { |l| color ? " #{color}#{l}#{LG}" : " #{l}" }
    end

    def facts(book)
      reads = library.reads(book)
      [book.language, book.issued[0, 4], "#{reads} read#{'s' unless reads == 1}"].reject(&:empty?).join(' . ')
    end

    def open_book(book)
      text = loading('opening the book...') { reading.open(book, seen: context[:seen] ||= Set.new) }
      return alert(refusal(text), color: YE) if text.is_a?(Symbol)

      each_pick(book.short_title.upcase[0, 26], text.chapters, right: "#{text.size} ch", label: :title) do |chapter|
        Reader.new(self, book, text).read(chapter.number)
      end
    end

    def refusal(why)
      case why
      when :too_big then "This book is longer than the #{reading.max_bytes / (1024 * 1024)} mb the board takes."
      when :empty then 'There is no text in this ebook, only the licence.'
      else 'Project Gutenberg did not give a plain text of this book. Try again later.'
      end
    end
  end
end

require_relative 'petscii/reader'
