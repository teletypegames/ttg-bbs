# frozen_string_literal: true

module UI
  module Modern
    # The helpers of the modern face (the methods of its Application): the
    # library's shelves and lists opened in windows, the search, opening an
    # RFC, its links and its QR code.
    module Library
      QR_PADDING = { sides: 2, top: 1, bottom: 0 }.freeze
      QR_SIDES   = 4
      QR_ROWS    = 7

      def library = services[:library]
      def reading = services[:reading]

      def classics = open_entries(library.own_shelves[0])

      def telnet = open_entries(library.own_shelves[1])

      def shelf_list = open_window(:shelves, shelves: library.shelves)

      def open_entries(shelf)
        return preparing if shelf.nil?

        entries = library.entries_on(shelf)
        open_window(:rfcs, entries: entries, title: " #{shelf.name} (#{entries.size}) ")
      end

      def newest
        return preparing unless library.ready?

        open_entries(library.shelves.find { |s| s.kind == :newest })
      end

      def search_text
        unless library.text_search?
          return BBS::Dialogs.message(self, 'The full text of every RFC is being mirrored from the RFC Editor and ' \
                                            'indexed. Try again later; the search of titles and abstracts (F3) works.',
                                      title: ' Search text ', width: 60)
        end

        BBS::Dialogs.input(self, prompt: 'Words anywhere in the text of the RFCs:', title: ' Search text ',
                                 value: context[:text_query].to_s, width: 64, on_submit: ->(query) { find_text(query) })
      end

      def find_text(query)
        context[:text_query] = query
        case (found = library.search_text(query))
        when :preparing then preparing
        when :too_short then search_says('A word of two letters or more, please.')
        when [] then search_says('No RFC has all these words.')
        else open_window(:rfcs, entries: found, title: " Text: #{query.strip[0, 40]} (#{found.size}) ")
        end
      end

      def this_month = open_entries(library.shelves.find { |s| s.kind == :month })

      def iens = open_entries(library.shelves.find { |s| s.kind == :ien })

      def most_read
        list = library.most_read
        return BBS::Dialogs.message(self, 'Nothing has been read here yet.', title: ' Most read ') if list.empty?

        open_window(:rfcs, entries: list, title: ' Most read on this board ')
      end

      def search
        BBS::Dialogs.input(self, prompt: 'A number (854, std 7) or words (status:standard, year:1983):',
                                 title: ' Search ', value: context[:query].to_s, width: 64,
                                 on_submit: ->(query) { find(query) })
      end

      def find(query)
        context[:query] = query
        case (found = library.search(query))
        when :preparing then preparing
        when :too_short then search_says('A word of two letters or more, please.')
        when [] then search_says('Nothing found. Fewer or other words?')
        when Array then found.first.is_a?(Symbol) ? search_says(refused(*found)) : search_found(query, found)
        end
      end

      def links(rfc)
        list = library.links(rfc)
        return BBS::Dialogs.message(self, "#{rfc.name} does not obsolete or update any other.", title: ' Links ') if
          list.empty?

        open_window(:rfcs, entries: list, title: " Links of #{rfc.name} ")
      end

      # The errata of +rfc+ in a TextWindow: what the RFC says and what it
      # should say, the verified ones first.
      def show_errata(rfc)
        list = library.errata(rfc)
        return BBS::Dialogs.message(self, "#{rfc.name} has no errata.", title: ' Errata ') if list.empty?

        TextWindow.open(self, title: "Errata of #{rfc.name} (#{list.size})", paragraphs: list.flat_map { |e| erratum(e) },
                              where: "rfc-editor.org/errata/rfc#{rfc.number}")
        :keep
      end

      # The RFCs and IENs the text of +rfc+ names, to open any of them.
      def references(rfc, doc)
        list = library.mentioned(reading.mentions(doc))
        return BBS::Dialogs.message(self, "#{rfc.name} names no other RFC.", title: ' References ') if list.empty?

        open_window(:rfcs, entries: list, title: " Named in #{rfc.name} (#{list.size}) ")
      end

      # The headings of +doc+; Enter moves +reader+ there.
      def contents(reader, rfc, doc) = open_window(:contents, headings: reading.contents(doc), rfc: rfc, reader: reader)

      def preparing
        BBS::Dialogs.message(self, 'The index is being prepared: it is downloaded from the RFC Editor and ' \
                                   'indexed. Try again in a minute. The Classics, Telnet and April 1st shelves ' \
                                   'are open meanwhile.', title: ' Index ', width: 60)
      end

      def open_rfc(rfc)
        doc = with_loading("Opening #{rfc.name}…") { reading.open(rfc, seen: context[:seen] ||= Set.new) }
        return ReaderWindow.open(self, reading: reading, rfc: rfc, doc: doc) unless doc.is_a?(Symbol)

        BBS::Dialogs.message(self, refusal(doc, rfc), title: ' Open ', width: 60)
      end

      def refusal(why, rfc)
        if why == :no_text then "The RFC Editor has no plain text of #{rfc.name}. See #{rfc.url}."
        else 'The RFC Editor did not answer. Try again in a minute.'
        end
      end

      # The RFC's page at the RFC Editor as a QR code, for a phone.
      def show_qr(rfc)
        code = qr_code(rfc.link, width: cols - QR_SIDES, height: rows - QR_ROWS)
        BBS::Windows::Info.open(self, title: " #{rfc.name} on your phone ",
                                      width: BBS::FrameBuffer.plain(code.first).size + QR_SIDES,
                                      body: code, padding: QR_PADDING)
        :keep
      rescue BBS::QR::TooLong
        BBS::Dialogs.message(self, "The screen is too small for a QR code. The RFC is at #{rfc.url}.", title: ' QR code ')
        :keep
      end

      def qr_code(link, **room)
        BBS::QR.ansi(link, **room)
      rescue BBS::QR::TooLong
        BBS::QR.ansi(link, **room, quiet: 1)
      end

      def selected(window) = window.list_widget.selected_item

      def help(text, title) = BBS::Dialogs.message(self, text, title: title, width: 64)

      private

      def erratum(e)
        [[:heading, ["Erratum #{e.id}", e.status, e.type, ("Section #{e.section}" unless e.section.empty?)].compact.join(' · ')],
         [:text, "Reported #{e.submitted}. It says:"], [:pre, e.orig_text], [:text, 'It should say:'], [:pre, e.correct_text],
         *([[:text, "Notes: #{e.notes.tr("\n", ' ')}"]] unless e.notes.strip.empty?)]
      end

      def search_says(text) = BBS::Dialogs.message(self, text, title: ' Search ')

      def search_found(query, entries)
        open_window(:rfcs, entries: entries, title: " Search: #{query.strip[0, 40]} (#{entries.size}) ")
      end

      def refused(why, number)
        return "There is no RFC #{number} yet." unless why == :not_issued

        "RFC #{number} was never issued: the number was given out, the RFC never came."
      end
    end
  end
end
