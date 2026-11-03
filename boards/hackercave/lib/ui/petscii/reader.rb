# frozen_string_literal: true

module UI
  module Petscii
    # The reader of the C64 face: an RFC reflowed to 38 columns
    # (ReflowService) in pages of ROWS lines, the headings white, the
    # figures cyan and their lines going on grey. RETURN turns the page, B
    # goes back one, Q goes back to the record.
    class Reader
      # Rows of text on a page: the title bar above, the key line below.
      ROWS = 21
      COLORS = { heading: WH, figure: CY, more: GR }.freeze

      def initialize(screen, reading, rfc, doc)
        @screen = screen
        @rfc    = rfc
        @lines  = reading.reflowed(doc, WIDTH).map { |l| line(l) }
      end

      # Reads from the first page until the caller goes back or turns past
      # the last.
      def read
        @page = 0
        loop do
          show_page
          case reader_key
          when :back then @page -= 1
          when :more then @page += 1
          else break
          end
          break if @page >= pages
        end
      ensure
        @screen.puts
      end

      private

      def pages = [(@lines.size + ROWS - 1) / ROWS, 1].max

      def last_page? = @page == pages - 1

      def show_page
        @page = @page.clamp(0, pages - 1)
        @screen.title(@rfc.name, "p#{@page + 1}/#{pages}")
        rows = @lines[@page * ROWS, ROWS]
        rows.each { |l| @screen.puts l }
        (ROWS - rows.size).times { @screen.puts }
        @screen.write " #{DG}ret:#{last_page? ? 'done' : 'more'}  b:back  q:record#{LG}"
      end

      def reader_key
        loop do
          k = @screen.key
          k = k.downcase if k.is_a?(String)
          case k
          when :enter, ' ', :down then return :more
          when 'b', :up then return :back
          when 'q', :escape then return :quit
          end
        end
      end

      # A reflowed line in characters the C64 has, indented by one, in the
      # colour of its kind.
      def line(reflowed)
        text = @screen.plain(reflowed.text)
        color = COLORS[reflowed.kind]
        color ? " #{color}#{text}#{LG}" : " #{text}"
      end
    end
  end
end
