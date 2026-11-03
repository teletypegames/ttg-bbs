# frozen_string_literal: true

module UI
  module Modern
    # A list of RFCs (a shelf, a search, the links of one, the most read)
    # on the left, the record of the one picked on the right; Enter reads
    # it.
    module RfcsWindow
      def self.define(app)
        app.window(:rfcs, type: :master_detail) do |w|
          frame(w)
          list(w)
          w.action(label: '&Read') { |win, ctx| on_selected(win, ctx) { |e| ctx[:app].open_rfc(e.rfc) } }
          w.action(label: '&Links') { |win, ctx| on_selected(win, ctx) { |e| ctx[:app].links(e.rfc) } }
          w.action(label: '&QR code') { |win, ctx| on_selected(win, ctx) { |e| ctx[:app].show_qr(e.rfc) } }
        end
      end

      def self.frame(w)
        w.maximizable true
        w.title         { |ctx| ctx[:title] }
        w.height        { |ctx| ctx[:app].rows - 8 }
        w.list_width    { |ctx| [38, (ctx[:app].cols / 2) - 4].min }
      end

      def self.list(w)
        w.items         { |ctx| ctx[:entries] }
        w.item_label    { |e, _ctx| label(e) }
        w.empty_message 'No RFCs here.'
        w.render_detail { |e, width, ctx| ctx[:app].rfc_lines(e, width) }
        w.bottom_meta { |e, _ctx| e.rfc.url }
        w.on_activate { |e, _window, ctx| ctx[:app].open_rfc(e.rfc) }
      end

      # The number and the title; a series ("STD 7") or a relation
      # ("obsoleted by") before them, the number of reads in the Most read
      # list.
      def self.label(entry)
        prefix = case entry.kind
                 when :reads then entry.note.to_s.rjust(3)
                 when :series then entry.note.ljust(7)
                 when :relation then entry.note.ljust(12)
                 end
        [prefix, entry.number.to_s.rjust(4), entry.rfc.title].compact.join('  ')
      end

      def self.on_selected(window, ctx)
        entry = ctx[:app].selected(window)
        yield entry if entry
        :keep
      end
    end
  end
end
