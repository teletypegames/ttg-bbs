# frozen_string_literal: true

require_relative 'petscii/screen'
require_relative 'petscii/reader'
require_relative 'logo'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen. A cursor menu,
  # the shelves and the books as numbered lists, a book's record on a page,
  # its chapters as a numbered list, and the reader: 38-column pages that
  # wait for RETURN, N and P for the next and the previous chapter.
  module Petscii
    LOGO_COLORS = [WH, WH, YE, YE, CY].freeze

    # SCRIPTORIUM in reversed blocks, five rows.
    def self.logo = BBS::BlockFont.petscii(Logo::WORD, colors: LOGO_COLORS, glyphs: Logo::GLYPHS)

    def self.masthead
      rule = " #{DG}#{'─' * (COLS - 2)}#{LG}"
      [rule, *logo, rule, "  #{WH}the classic literature vault#{LG}",
       "  #{GR}project gutenberg, chapter by chapter#{LG}", rule]
    end

    def self.flow(bbs)
      BBS::Flow.define do
        call do |ctx, runner|
          Board.new(bbs.library, bbs.reading, Screen.new(runner.session), ctx).run
          nil
        end
        call do |_ctx, runner|
          BBS::Goodbye.petscii(Screen.new(runner.session), title: 'scriptorium bbs', color: LB, width: 38,
                                                            note: 'The books are the gift of Project Gutenberg.')
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    # One call: the menu, the shelves, the books, the reader.
    class Board
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

      def initialize(library, reading, screen, ctx)
        @library = library
        @reading = reading
        @screen  = screen
        @ctx     = ctx
        @seen    = Set.new
      end

      def run
        @screen.cls
        Petscii.masthead.each { |l| @screen.puts l }
        loop do
          @screen.puts
          @screen.puts " #{GR}#{catalog_line}#{LG}"
          @choice = @screen.menu(menu_items, index: menu_items.index { |i| i.value == @choice }, back: 'q',
                                             hint: 'crsr: choose  return: take')
          case @choice
          when '1' then books('CLASSICS', @library.books_on(@library.classics_shelf))
          when '2' then shelves
          when '3' then search
          when '4' then most_read
          when 'a' then @screen.page('ABOUT', ABOUT)
          when 'q' then return
          end
          @screen.title('SCRIPTORIUM BBS', catalog_note)
        end
      end

      private

      def menu_items
        @menu_items ||= [
          BBS::Selector.item('the classics shelf', key: '1', value: '1', about: 'the great books, open at once'),
          BBS::Selector.item('gutenberg bookshelves', key: '2', value: '2', about: 'the shelves of project gutenberg'),
          BBS::Selector.item('search by title or author', key: '3', value: '3', about: 'words, and lang:fr for one language'),
          BBS::Selector.item('most read on this board', key: '4', value: '4', about: 'what the callers here read'),
          BBS::Selector.item('about', key: 'a', value: 'a', about: 'the board, the books, the reader keys'),
          BBS::Selector.item('log off', key: 'q', value: 'q', about: 'hang up. see you!')
        ]
      end

      def catalog_line = @library.ready? ? "#{@library.count} books in the catalog" : 'the catalog is being prepared'

      def catalog_note = @library.ready? ? "#{@library.count} books" : ''

      def not_ready
        @screen.puts
        @screen.say('The catalog is being prepared: it is downloaded from Project Gutenberg and indexed. ' \
                    'Try again in a minute. The classics shelf is open meanwhile.', YE)
        @screen.pause
      end

      def shelves
        return not_ready unless @library.ready?

        list = @library.shelves.drop(1)
        loop do
          shelf = @screen.pick('BOOKSHELVES', list, right: "#{list.size} shelves") do |s|
            "#{s.label.downcase} #{GR}#{s.count}#{LG}"
          end
          return unless shelf

          books(shelf.label.upcase, @library.books_on(shelf))
        end
      end

      def search
        return not_ready unless @library.ready?

        @screen.title('SEARCH')
        @screen.say('Words of the title or the author. Add lang:fr (de, es, ...) for one language.', GR)
        @screen.puts
        query = BBS::Field.ask(@screen.session, ' search> ', max: 60)
        return if query.nil? || query.strip.empty?

        case (found = @library.search(query))
        when :too_short then message('A word of two letters or more, please.')
        when [] then message('Nothing found. Fewer or other words?')
        else books("SEARCH: #{query.strip.upcase}"[0, 28], found)
        end
      end

      def most_read
        list = @library.most_read
        return message('Nothing has been read here yet. Be the first!') if list.empty?

        counts = list.to_h { |b, n| [b.id, n] }
        books('MOST READ HERE', list.map(&:first)) { |b| "#{GR}#{counts[b.id]}#{LG} #{b.short_title}" }
      end

      def message(text)
        @screen.puts
        @screen.say(text, YE)
        @screen.pause
      end

      def books(heading, list, &label)
        label ||= :short_title.to_proc
        loop do
          book = @screen.pick(heading, list, empty: 'no books here.', right: "#{list.size} books", &label)
          return unless book

          info(book)
        end
      end

      def info(book)
        @screen.page("EBOOK ##{book.id}", record(book), wait: false)
        open_book(book) if @screen.actions(%w[r read], %w[q back]) == 'r'
      end

      # A book's record: the title, the author, the facts, the subjects and
      # the credit.
      def record(book)
        subjects = @screen.plain(book.subject_list.first(3).join('; '))
        credit   = "ebook ##{book.id} from project gutenberg, #{book.url} - public domain in the usa."
        [*lines(@screen.plain(book.short_title), WH), *lines(@screen.plain("by #{book.author}"), CY),
         " #{GR}#{facts(book)}#{LG}", *(['', *lines(subjects)] unless subjects.empty?), '', *lines(credit, GR)]
      end

      # +text+ wrapped, each line indented and in +color+.
      def lines(text, color = nil)
        @screen.wrap(text).map { |l| color ? " #{color}#{l}#{LG}" : " #{l}" }
      end

      def facts(book)
        reads = @library.reads(book)
        [book.language, book.issued[0, 4], "#{reads} read#{'s' unless reads == 1}"].reject(&:empty?).join(' . ')
      end

      def open_book(book)
        @screen.puts " #{GR}opening the book...#{LG}"
        text = @reading.open(book, seen: @seen)
        if text.is_a?(Symbol)
          message(refusal(text))
          return
        end

        loop do
          chapter = @screen.pick(book.short_title.upcase[0, 26], text.chapters, right: "#{text.size} ch", &:title)
          return unless chapter

          Reader.new(@screen, @reading, book, text).read(chapter.number)
        end
      end

      def refusal(why)
        case why
        when :too_big then "This book is longer than the #{@reading.max_bytes / (1024 * 1024)} mb the board takes."
        when :empty then 'There is no text in this ebook, only the licence.'
        else 'Project Gutenberg did not give a plain text of this book. Try again later.'
        end
      end
    end
  end
end
