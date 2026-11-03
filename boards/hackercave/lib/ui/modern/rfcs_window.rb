# frozen_string_literal: true

module UI
  module Modern
    # A list of RFCs (a shelf, a search, the links of one, the most read)
    # on the left, the record of the one picked on the right; Enter reads
    # it.
    module RfcsWindow
      # The buttons under the list, each a helper of the Application that
      # takes the RFC picked.
      ACTIONS = [['&Read', :open_rfc], ['&Links', :links], ['&Errata', :show_errata], ['&QR code', :show_qr]].freeze

      def self.define(app)
        app.window(:rfcs, type: :master_detail) do |w|
          frame(w)
          list(w)
          ACTIONS.each { |label, helper|
            w.action(label: label) { |win, ctx|
              on_selected(win, ctx) { |e|
                ctx[:app].send(helper, e.rfc)
              }
            }
          }
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

      # The number and the title; a series ("STD 7"), a relation
      # ("obsoleted by"), the line it is named on, the year, or the number of
      # reads before them.
      def self.label(entry)
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

      def self.on_selected(window, ctx)
        entry = ctx[:app].selected(window)
        yield entry if entry
        :keep
      end
    end
  end
end
