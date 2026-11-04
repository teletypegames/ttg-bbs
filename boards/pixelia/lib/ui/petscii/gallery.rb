# frozen_string_literal: true

module UI
  class Petscii < BBS::Petscii::Face
    # The 16colo.rs gallery on a C64: the years, a year's packs and a pack's
    # files as numbered cursor lists, the credits of a piece, then the piece itself
    # in pages of 22 rows, 40 columns at a time (the left half of an 80
    # column piece first; R or CRSR right shows the next 40, CRSR left the
    # ones before).
    module Gallery
      PAGE_ROWS = 22
      HALF      = 40
      # A " this near the right edge would leave the C64 in quote mode (see
      # BBS::Petscii::Encoder), so there it is an apostrophe.
      QUOTE_FROM = HALF - 3
      NO_ANSWER  = '16colo.rs did not answer. Try again later.'
      PIECE      = { too_big: 'This piece is too large for the board.', unavailable: NO_ANSWER }.freeze

      private

      def gallery_years
        title('16COLO.RS')
        years = loading('reading the archive…', failed: NO_ANSWER) { gallery.years }

        each_pick('16COLO.RS  ANSI ART BY YEAR', years, right: "#{years.size} years",
                                                       label: ->(y) { "#{y.year} #{GR}#{y.packs} packs#{LG}" }) do |year|
          gallery_year(year)
        end
      end

      def gallery_year(year)
        title("16COLO.RS #{year.year}")
        packs = loading("reading #{year.packs} packs…", failed: NO_ANSWER) { gallery.packs(year) }

        each_pick("16COLO.RS #{year.year}", packs, right: "#{packs.size} packs",
                                                   label: ->(p) { "#{p.name} #{GR}#{p.credits}#{LG}" }) do |pack|
          gallery_pack(pack)
        end
      end

      def gallery_pack(pack)
        title(pack.name)
        files = loading('reading the pack…', failed: NO_ANSWER) { gallery.files(pack) }

        each_pick(pack.name, files, empty: 'no text art in this pack.', right: "#{files.size} files",
                                    label: ->(f) { "#{f.name} #{GR}#{f.credits}#{LG}" }) do |file|
          gallery_piece(pack, file)
        end
      end

      def gallery_piece(pack, file)
        page(file.name, credits(pack, file), wait: false)
        return if actions([nil, 'view'], %w[q back]) == 'q'

        art = loading('fetching…') { gallery.piece(file) }
        art.is_a?(Symbol) ? report(art, PIECE) : show_piece(file, art)
      end

      def credits(pack, file)
        [" #{WH}#{file.title.empty? ? file.name : file.title}#{LG}",
         " #{CY}#{file.credits}#{LG}", '',
         " #{GR}file#{LG}  #{file.name}", " #{GR}pack#{LG}  #{pack.name} (#{pack.year})",
         (" #{GR}date#{LG}  #{file.date}" unless file.date.empty?),
         (" #{GR}by#{LG}    #{file.artists.join(', ')}" unless file.artists.empty?), '',
         " #{GR}#{gallery.file_url(file)}#{LG}"].compact
      end

      def show_piece(file, art)
        top   = 0
        left  = 0
        pages = [(art.height + PAGE_ROWS - 1) / PAGE_ROWS, 1].max
        loop do
          draw_piece(file, art, top, left, pages)
          case key
          when :enter, 'n', 'N', :down, ' '
            return if (top / PAGE_ROWS) + 1 >= pages

            top += PAGE_ROWS
          when 'p', 'P', :up then top = [top - PAGE_ROWS, 0].max
          when 'r', 'R', :right then left = left + HALF < art.width ? left + HALF : 0
          when :left then left = [left - HALF, 0].max
          when 'q', 'Q', :escape then return
          end
        end
      end

      def draw_piece(file, art, top, left, pages)
        half = " col #{left + 1}" if art.width > HALF
        title("#{file.name}#{half}", "#{(top / PAGE_ROWS) + 1}/#{pages}")
        pen = Pen.new
        write(PAGE_ROWS.times.map { |i| pen.row(page_row(art, top + i, left), HALF) }.join)
        right = art.width > HALF ? "  #{YE}R#{LG} right" : ''
        write("#{BBS::Ansi::RESET}#{RO} #{YE}ret#{LG} next #{YE}P#{LG} back#{right}  #{YE}Q#{LG} quit")
      end

      # Row +y+ of +art+ from column +left+, 40 C64 cells.
      def page_row(art, y, left)
        cells = art.cells(y, left, HALF).map { |c| Pen.art(*c) }
        cells[QUOTE_FROM..].each { |c| c[0] = "'" if c[0] == '"' }
        cells
      end
    end
  end
end
