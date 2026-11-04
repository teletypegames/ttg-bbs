# frozen_string_literal: true

module UI
  module Modern
    # The helpers of the modern face: the library's shelves and lists opened
    # in windows, the searches, opening an RFC, its links, its errata, the
    # RFCs it names and its QR code.
    module Library
      NOT_READY = 'The index is being prepared: it is downloaded from the RFC Editor and indexed. Try again in a ' \
                  'minute. The Classics, Telnet and April 1st shelves are open meanwhile.'
      NO_MIRROR = 'The full text of every RFC is being mirrored from the RFC Editor and indexed. Try again later; ' \
                  'the search of titles and abstracts (F3) works.'
      TOO_SHORT = 'A word of two letters or more, please.'
      SEARCH_PROMPT = 'A number (854, std 7) or words (status:standard, year:1983):'

      # The size of the index for the statusbar.
      def index_status
        return 'preparing the index…' unless library.ready?

        "#{library.count.to_s.reverse.scan(/\d{1,3}/).join(',').reverse} RFCs"
      end

      def classics = open_entries(library.own_shelves[0])

      def telnet = open_entries(library.own_shelves[1])

      def this_month = open_entries(library.shelves.find { |s| s.kind == :month })

      def iens = open_entries(library.shelves.find { |s| s.kind == :ien })

      def shelf_list = show(:shelves, shelves: library.shelves)

      def newest
        return preparing unless library.ready?

        open_entries(library.shelves.find { |s| s.kind == :newest })
      end

      def open_entries(shelf)
        return preparing if shelf.nil?

        entries = library.entries_on(shelf)
        show(:rfcs, entries: entries, heading: "#{shelf.name} (#{entries.size})")
      end

      def most_read
        list = library.most_read
        return message('Nothing has been read here yet.', title: 'Most read') if list.empty?

        show(:rfcs, entries: list, heading: 'Most read on this board')
      end

      def search
        ask(SEARCH_PROMPT, title: 'Search', value: context[:query].to_s, width: 64) { |query| find(query) }
      end

      def find(query)
        context[:query] = query
        case (found = library.search(query))
        when :preparing then preparing
        when :too_short then message(TOO_SHORT, title: 'Search')
        when [] then message('Nothing found. Fewer or other words?', title: 'Search')
        when Array
          return message(refused(*found), title: 'Search') if found.first.is_a?(Symbol)

          show(:rfcs, entries: found, heading: "Search: #{query.strip[0, 40]} (#{found.size})")
        end
      end

      def search_text
        return message(NO_MIRROR, title: 'Search text', width: 60) unless library.text_search?

        ask(
          'Words anywhere in the text of the RFCs:',
          title: 'Search text',
          value: context[:text_query].to_s,
          width: 64
        ) { |query| find_text(query) }
      end

      def find_text(query)
        context[:text_query] = query
        case (found = library.search_text(query))
        when :preparing then preparing
        when :too_short then message(TOO_SHORT, title: 'Search')
        when [] then message('No RFC has all these words.', title: 'Search')
        else show(:rfcs, entries: found, heading: "Text: #{query.strip[0, 40]} (#{found.size})")
        end
      end

      def links(rfc)
        list = library.links(rfc)
        return message("#{rfc.name} does not obsolete or update any other.", title: 'Links') if list.empty?

        show(:rfcs, entries: list, heading: "Links of #{rfc.name}")
      end

      # The errata of +rfc+, what the RFC says and what it should say, the
      # verified ones first.
      def show_errata(rfc)
        list = library.errata(rfc)
        return message("#{rfc.name} has no errata.", title: 'Errata') if list.empty?

        show(
          :text,
          heading:    "Errata of #{rfc.name} (#{list.size})",
          paragraphs: list.flat_map { |e| erratum(e) },
          credit:     "rfc-editor.org/errata/rfc#{rfc.number}"
        )
      end

      # The RFCs and IENs the text of +rfc+ names, to open any of them.
      def references(rfc, doc)
        list = library.mentioned(reading.mentions(doc))
        return message("#{rfc.name} names no other RFC.", title: 'References') if list.empty?

        show(:rfcs, entries: list, heading: "Named in #{rfc.name} (#{list.size})")
      end

      # The headings of +doc+; Enter moves +reader+ there.
      def contents(reader, rfc, doc) = show(:contents, headings: reading.contents(doc), rfc: rfc, reader: reader)

      def open_rfc(rfc)
        doc = loading("Opening #{rfc.name}…") { reading.open(rfc, seen: context[:seen] ||= Set.new) }
        return message(refusal(doc, rfc), title: 'Open', width: 60) if doc.is_a?(Symbol)

        show(:reader, rfc: rfc, doc: doc)
      end

      # The RFC's page at the RFC Editor as a QR code, for a phone.
      def show_qr(rfc) = qr(rfc.link, title: "#{rfc.name} on your phone")

      def preparing = message(NOT_READY, title: 'Index', width: 60)

      private

      def refusal(why, rfc)
        return "The RFC Editor has no plain text of #{rfc.name}. See #{rfc.url}." if why == :no_text

        'The RFC Editor did not answer. Try again in a minute.'
      end

      def refused(why, number)
        return "There is no RFC #{number} yet." unless why == :not_issued

        "RFC #{number} was never issued: the number was given out, the RFC never came."
      end

      def erratum(e)
        [[:heading, ["Erratum #{e.id}", e.status, e.type, ("Section #{e.section}" unless e.section.empty?)].compact.join(' · ')],
         [:text, "Reported #{e.submitted}. It says:"], [:pre, e.orig_text], [:text, 'It should say:'], [:pre, e.correct_text],
         *([[:text, "Notes: #{e.notes.tr("\n", ' ')}"]] unless e.notes.strip.empty?)]
      end
    end
  end
end
