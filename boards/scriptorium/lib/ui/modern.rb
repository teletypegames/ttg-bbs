# frozen_string_literal: true

require_relative 'logo'
require_relative 'modern/reader_window'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): a desktop
  # under a menubar, the shelves and their books in two-pane windows with a
  # book's record on the right, a search box, a book's chapters with the
  # start of the one picked, and a reader window (lib/ui/modern/reader_window).
  module Modern
    ABOUT = 'Scriptorium BBS — the classic literature vault of Teletype Games, powered by rubbs. ' \
            'Tens of thousands of books from Project Gutenberg (gutenberg.org), cut into chapters for your ' \
            'terminal. The texts are public domain in the USA; check the laws of your country before you ' \
            'pass them on. Thanks to Project Gutenberg and its volunteers, who made them.'

    def self.flow(bbs)
      app = BBS::Application.define do
        theme BBS::Theme.synchronet
        services bbs.services

        helpers do
          def library = services[:library]
          def reading = services[:reading]

          def classics = open_books(library.classics_shelf)

          def shelf_list
            return preparing unless library.ready?

            open_window(:shelves, shelves: library.shelves)
          end

          def open_books(shelf)
            books = library.books_on(shelf)
            title = shelf.classics? ? ' Classics ' : " #{shelf.label} (#{books.size} of #{shelf.count}) "
            open_window(:books, books: books, title: title)
          end

          def most_read
            list = library.most_read
            return BBS::Dialogs.message(self, 'Nothing has been read here yet.', title: ' Most read ') if list.empty?

            open_window(:books, books: list.map(&:first), title: ' Most read on this board ',
                                counts: list.to_h { |b, n| [b.id, n] })
          end

          def search
            BBS::Dialogs.input(self, prompt: 'Title or author words (lang:fr for one language):', title: ' Search ',
                                     value: context[:query].to_s, width: 64,
                                     on_submit: ->(query) { find(query) })
          end

          def find(query)
            context[:query] = query
            case (books = library.search(query))
            when :preparing then preparing
            when :too_short then BBS::Dialogs.message(self, 'A word of two letters or more, please.', title: ' Search ')
            when [] then BBS::Dialogs.message(self, 'Nothing found. Fewer or other words?', title: ' Search ')
            else open_window(:books, books: books, title: " Search: #{query.strip[0, 40]} (#{books.size}) ")
            end
          end

          def preparing
            BBS::Dialogs.message(self, 'The catalog is being prepared: it is downloaded from Project Gutenberg ' \
                                       'and indexed. Try again in a minute. The Classics shelf is open meanwhile.',
                                 title: ' Catalog ', width: 60)
          end

          def open_book(book)
            title = book.short_title[0, 36]
            text = with_loading("Opening #{title}…") { reading.open(book, seen: context[:seen] ||= Set.new) }
            return open_window(:chapters, book: book, text: text) unless text.is_a?(Symbol)

            BBS::Dialogs.message(self, refusal(text), title: ' Open book ', width: 60)
          end

          def refusal(why)
            case why
            when :too_big then "This book is longer than the #{reading.max_bytes / (1024 * 1024)} MB the board takes."
            when :empty then 'There is no text in this ebook, only the licence. It may be a picture or a recording.'
            else 'Project Gutenberg did not give a plain text of this book. It may only have another format, ' \
                 'or the site may be busy: try again later.'
            end
          end

          def read(book, text, number) = ReaderWindow.open(self, reading: reading, book: book, text: text, number: number)

          def selected(window) = window.list_widget.selected_item

          def book_lines(book, width)
            t = theme
            wrap = ->(s) { BBS::FrameBuffer.wrap_ansi(s, width - 1) }
            reads = library.reads(book)
            lines = wrap.call("#{t[:text_bright]}#{book.short_title}#{t[:text]}")
            lines.concat(wrap.call("#{t[:text_dim]}#{book.subtitle}#{t[:text]}")) unless book.subtitle.empty?
            authors = book.author_names.empty? ? 'Anonymous' : book.author_names.join(', ')
            lines.concat(wrap.call("#{t[:accent]}by #{authors}#{t[:text]}"))
            facts = ["Language: #{book.language}", ("Issued: #{book.issued}" unless book.issued.empty?),
                     "Read #{reads} time#{'s' unless reads == 1} here"].compact
            lines.concat(wrap.call("#{t[:text_dim]}#{facts.join(' · ')}#{t[:text]}"))
            lines << ''
            unless book.subjects.empty?
              lines.concat(wrap.call("#{t[:label]}Subjects:#{t[:text]} #{book.subject_list.first(6).join('; ')}"))
            end
            unless book.bookshelves.empty?
              lines.concat(wrap.call("#{t[:label]}Bookshelves:#{t[:text]} #{book.shelf_names.first(6).join('; ')}"))
            end
            lines << '' unless book.subjects.empty? && book.bookshelves.empty?
            lines.concat(wrap.call("eBook ##{book.id} from Project Gutenberg, #{book.url} — public domain in the USA."))
            lines << ''
            lines.concat(wrap.call("#{t[:text_dim]}Enter opens the book.#{t[:text]}"))
          end

          def status_text
            count = library.count.to_s.reverse.scan(/\d{1,3}/).join(',').reverse
            books = library.ready? ? "#{count} books" : 'preparing the catalog…'
            "#{books} │ #{Time.now.strftime('%H:%M')}"
          end

          def desktop_label(text, style, x, y, width, align: :left)
            label = BBS::Widgets::Label.new(text: text, align: align, style_key: style)
            label.layout(x, y, width, 1)
            add(label)
          end
        end

        window :shelves, type: :master_detail do |w|
          w.maximizable true
          w.title         ' Bookshelves '
          w.height        { |ctx| ctx[:app].rows - 8 }
          w.list_width    { |ctx| [34, (ctx[:app].cols / 2) - 4].min }
          w.items         { |ctx| ctx[:shelves] }
          w.item_label    { |s, _ctx| s.label }
          w.empty_message 'No bookshelves yet.'
          w.render_detail do |s, width, ctx|
            t = ctx[:app].theme
            kind = if s.classics? then 'The board\'s own shelf of well-known books.'
                   elsif s.category? then 'A category of Project Gutenberg.'
                   else 'A bookshelf of Project Gutenberg, gathered by its volunteers.'
                   end
            ["#{t[:text_bright]}#{s.label}#{t[:text]}", "#{t[:accent]}#{s.count} books#{t[:text]}", '',
             *BBS::FrameBuffer.wrap_ansi(kind, width - 1), '',
             *BBS::FrameBuffer.wrap_ansi("#{t[:text_dim]}The first #{LibraryService::SHELF_LIMIT} by ebook number " \
                                         "are listed: the oldest ebooks are the best known ones.#{t[:text]}", width - 1)]
          end
          w.bottom_meta { |_s, _ctx| 'Enter opens the shelf' }
          w.on_activate { |s, _window, ctx| ctx[:app].open_books(s) }
          w.action(label: '&Open') do |win, ctx|
            shelf = ctx[:app].selected(win)
            ctx[:app].open_books(shelf) if shelf
            :keep
          end
        end

        window :books, type: :master_detail do |w|
          w.maximizable true
          w.title         { |ctx| ctx[:title] }
          w.height        { |ctx| ctx[:app].rows - 8 }
          w.list_width    { |ctx| [36, (ctx[:app].cols / 2) - 4].min }
          w.items         { |ctx| ctx[:books] }
          w.item_label do |b, ctx|
            count = ctx[:counts]&.fetch(b.id, nil)
            count ? "#{count.to_s.rjust(3)}  #{b.short_title}" : b.short_title
          end
          w.empty_message 'No books here.'
          w.render_detail { |b, width, ctx| ctx[:app].book_lines(b, width) }
          w.bottom_meta { |b, _ctx| "eBook ##{b.id} · #{b.language}" }
          w.on_activate { |b, _window, ctx| ctx[:app].open_book(b) }
          w.action(label: '&Read') do |win, ctx|
            book = ctx[:app].selected(win)
            ctx[:app].open_book(book) if book
            :keep
          end
        end

        window :chapters, type: :master_detail do |w|
          w.maximizable true
          w.title         { |ctx| " #{ctx[:book].short_title[0, 50]} " }
          w.height        { |ctx| ctx[:app].rows - 8 }
          w.list_width    { |ctx| [40, (ctx[:app].cols / 2) - 4].min }
          w.items         { |ctx| ctx[:text].chapters }
          w.item_label    { |c, ctx| "#{c.number.to_s.rjust(ctx[:text].size.to_s.size)}. #{c.title}" }
          w.empty_message 'No chapters.'
          w.render_detail do |c, width, ctx|
            t = ctx[:app].theme
            preview = ctx[:app].reading.preview(ctx[:text], c.number).to_s
            ["#{t[:text_bright]}#{c.title}#{t[:text]}",
             "#{t[:accent]}Chapter #{c.number} of #{ctx[:text].size} · #{(c.length / 1024.0).ceil} KB#{t[:text]}", '',
             *BBS::FrameBuffer.wrap_ansi("#{preview}…", width - 1), '',
             *BBS::FrameBuffer.wrap_ansi("#{t[:text_dim]}Enter reads it.#{t[:text]}", width - 1)]
          end
          w.bottom_meta { |_c, ctx| "eBook ##{ctx[:book].id} from Project Gutenberg · #{ctx[:book].url}" }
          w.on_activate { |c, _window, ctx| ctx[:app].read(ctx[:book], ctx[:text], c.number) }
          w.action(label: '&Read') do |win, ctx|
            chapter = ctx[:app].selected(win)
            ctx[:app].read(ctx[:book], ctx[:text], chapter.number) if chapter
            :keep
          end
        end

        menubar do
          menu '&Library' do
            item '&Classics',    shortcut: 'F2' do classics end
            item '&Search…',     shortcut: 'F3' do search end
            item '&Bookshelves', shortcut: 'F4' do shelf_list end
            item '&Most read',   shortcut: 'F7' do most_read end
            separator
            item '&Log off', shortcut: 'Alt-X' do :halt end
          end
          menu '&Help' do
            item '&About' do BBS::Dialogs.message(self, ABOUT, title: ' About ', width: 64) end
            item '&Reading' do
              BBS::Dialogs.message(self,
                'Pick a book and press Enter: the board fetches its text from Project Gutenberg once, cuts it into ' \
                'chapters, and keeps it for the next reader. In the reader: PgUp/PgDn and the arrows scroll, Home/End ' \
                'go to the ends of the chapter, ← and → (or P and N) turn to the previous and the next chapter. ' \
                'F5 gives the reader the whole screen.',
                title: ' Reading ', width: 64)
            end
            item '&Keys' do
              BBS::Dialogs.message(self,
                'F2 Classics · F3 Search · F4 Bookshelves · F7 Most read · Enter — open · Alt+letter — the ' \
                'buttons and the menus · Tab/Shift-Tab — move focus · Esc — close window · F5 or Alt-Enter — full ' \
                'screen and back · F6 / Shift-F6 — next / previous window · F10 Menu · Alt-X Log off',
                title: ' Keys ', width: 64)
            end
          end
        end

        status_hint('F2', 'Classics') { classics }
        status_hint('F3', 'Search') { search }
        status_hint('F4', 'Shelves') { shelf_list }
        status_hint('F7', 'Most read') { most_read }
        status_hint('F10', 'Menu', hidden: true) { menubar.open(0) }
        status_hint('Alt-X', 'Bye') { :halt }

        on_tick { statusbar.right_text = status_text }

        init do
          mark = ((cols - Logo.half_blocks.first.length) / 2) + 1
          Logo.half_blocks.each_with_index { |row, i| desktop_label(row, :accent, mark, 2 + i, row.length) }
          desktop_label('─── the classic literature vault · books from Project Gutenberg ───', :text_dim, 1, rows - 2,
                        cols, align: :center)
          statusbar.right_text = status_text
          classics
        end
      end

      BBS::Flow.define do
        call do |ctx, runner|
          app.run(session: runner.session, session_id: ctx[:session_id], context: ctx)
          nil
        end
        call do |_ctx, runner|
          runner.write "\e[0m\e[2J\e[H\r\n  \e[1;37mThanks for calling Scriptorium BBS.\e[0m\r\n  " \
                       "\e[2;37mThe books are Project Gutenberg's gift. More of us: teletypegames.org\e[0m\r\n\r\n  " \
                       "\e[1;31mNO CARRIER\e[0m\r\n\r\n"
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end
  end
end
