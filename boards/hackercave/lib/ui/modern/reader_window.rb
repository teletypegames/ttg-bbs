# frozen_string_literal: true

module UI
  module Modern
    # An RFC as the RFC Editor published it: its lines unchanged, in a pane
    # at least 72 columns wide when the screen allows (the running heads and
    # feet of the pages dim, the headings bright, the RFCs it names in the
    # accent colour), and a line under the text that says where the reader
    # is: "RFC 793 · page 3/91 · line 140/5247". Contents jumps to a
    # heading, References lists the RFCs named, Links the ones it obsoletes
    # or updates.
    module ReaderWindow
      extend Rubbs::Modern::Part

      window :reader, :reader do
        title     { "#{rfc.name}: #{rfc.title[0, 50]}" }
        max_width 78
        lines     { rfc_text(doc) }
        where     { |view| rfc_where(rfc, doc, view) }
        action('C&ontents')  { |reader| contents(reader, rfc, doc) }
        action('References') { references(rfc, doc) }
        action('Links')      { links(rfc) }
        action('QR code')    { show_qr(rfc) }
      end

      helpers do
        def rfc_text(doc)
          kinds = reading.kinds(doc)
          doc.lines.each_with_index.map do |line, i|
            case kinds[i]
            when :page then dim(line)
            when :heading then bright(line)
            else line.gsub(ReadingService::MENTION) { |m| accent(m) }
            end
          end
        end

        def rfc_where(rfc, doc, view)
          last = [view.scroll + view.bounds.height, doc.size].min
          page = doc.paged? ? "page #{doc.page_of(view.scroll)}/#{doc.pages} · " : ''
          "#{rfc.name} · #{page}line #{last}/#{doc.size} · #{100 * last / [doc.size, 1].max}%"
        end
      end
    end
  end
end
