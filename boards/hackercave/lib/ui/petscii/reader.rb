# frozen_string_literal: true

module UI
  module Petscii
    # The reader of the C64 face: an RFC reflowed to 38 columns
    # (ReflowService) in pages of ROWS lines, the headings white, the
    # figures cyan and their lines going on grey. RETURN turns the page, B
    # goes back one, T picks a heading to go to, F lists the RFCs it names
    # (+on_named+ gets them), Q goes back to the record.
    class Reader
      # Rows of text on a page: the title bar above, the key line below.
      ROWS = 21
      COLORS = { heading: WH, figure: CY, more: GR }.freeze

      def initialize(screen, reading, rfc, doc, on_named: nil)
        @screen   = screen
        @reading  = reading
        @rfc      = rfc
        @doc      = doc
        @on_named = on_named
        @flowed   = reading.reflowed(doc, WIDTH)
        @lines    = @flowed.map { |l| line(l) }
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
          when :contents then contents
          when :named then @on_named&.call(@reading.mentions(@doc))
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
        @screen.write " #{DG}ret:#{last_page? ? 'done' : 'more'} b:back t:contents f:rfcs q#{LG}"
      end

      def reader_key
        loop do
          k = @screen.key
          k = k.downcase if k.is_a?(String)
          case k
          when :enter, ' ', :down then return :more
          when 'b', :up then return :back
          when 't' then return :contents
          when 'f' then return :named
          when 'q', :escape then return :quit
          end
        end
      end

      # The headings of the reflowed RFC (the first line of each); the one
      # picked turns to its page.
      def contents
        heads = headings
        picked = @screen.pick("CONTENTS #{@rfc.name}", heads, empty: 'no headings found.', right: "#{heads.size} ") do |(_, text)|
          text.strip.downcase
        end
        @page = picked.first / ROWS if picked
      end

      # [index, text] of every reflowed line that starts a heading.
      def headings
        @flowed.each_with_index.filter_map do |l, i|
          [i, l.text] if l.kind == :heading && (i.zero? || @flowed[i - 1].kind != :heading)
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
