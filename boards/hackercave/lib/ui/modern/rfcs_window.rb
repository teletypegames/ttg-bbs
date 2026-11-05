# frozen_string_literal: true

module UI
  module Modern
    # A list of RFCs (a shelf, a search, the links of one, the most read)
    # on the left, the record of the one picked on the right; Enter reads
    # it.
    module RfcsWindow
      extend Rubbs::Modern::Part

      window :rfcs, :master_detail do
        title      { heading }
        height     { rows - 8 }
        list_width { [38, (cols / 2) - 4].min }
        items      { entries }
        label      { |e| entry_label(e) }
        empty      'No RFCs here.'
        detail     { |e| rfc_lines(e) }
        meta       { |e| e.rfc.url }
        on_pick    { |e| open_rfc(e.rfc) }
        action('Read')    { |e| open_rfc(e.rfc) }
        action('Links')   { |e| links(e.rfc) }
        action('Errata')  { |e| show_errata(e.rfc) }
        action('QR code') { |e| show_qr(e.rfc) }
      end

      helpers do
        # The number and the title; a series ("STD 7"), a relation
        # ("obsoleted by"), the line it is named on, the year, or the number
        # of reads before them.
        def entry_label(entry)
          prefix = case entry.kind
                   when :reads then entry.note.to_s.rjust(3)
                   when :series then entry.note.ljust(7)
                   when :relation then entry.note.ljust(12)
                   when :line then "l.#{entry.note}".ljust(6)
                   when :year then entry.note
                   end
          number = entry.rfc.ien? ? "IEN #{entry.rfc.serial}" : entry.number.to_s.rjust(4)
          [prefix, number, entry.rfc.title].compact.join('  ')
        end
      end
    end
  end
end
