# frozen_string_literal: true

require_relative 'pen'

module UI
  module Petscii
    # The 16colo.rs gallery on a C64: the years, a year's packs and a pack's
    # files as numbered cursor lists, the credits of a piece, then the piece itself
    # in pages of 22 rows, 40 columns at a time (the left half of an 80
    # column piece first; R or CRSR right shows the next 40, CRSR left the
    # ones before).
    class Gallery
      PAGE_ROWS = 22
      HALF      = 40
      # A " this near the right edge would leave the C64 in quote mode (see
      # BBS::Petscii::Encoder), so there it is an apostrophe.
      QUOTE_FROM = HALF - 3

      def initialize(gallery, screen)
        @gallery = gallery
        @screen  = screen
      end

      def run
        @screen.title('16COLO.RS')
        @screen.puts " #{GR}reading the archive…#{LG}"
        years = @gallery.years
        return unavailable unless years

        loop do
          year = @screen.pick('16COLO.RS  ANSI ART BY YEAR', years, right: "#{years.size} years") do |y|
            "#{y.year} #{GR}#{y.packs} packs#{LG}"
          end
          return unless year

          year(year)
        end
      end

      private

      def year(year)
        @screen.title("16COLO.RS #{year.year}")
        @screen.puts " #{GR}reading #{year.packs} packs…#{LG}"
        packs = @gallery.packs(year)
        return unavailable unless packs

        loop do
          pack = @screen.pick("16COLO.RS #{year.year}", packs, right: "#{packs.size} packs") do |p|
            "#{p.name} #{GR}#{p.credits}#{LG}"
          end
          return unless pack

          pack(pack)
        end
      end

      def pack(pack)
        @screen.title(pack.name)
        @screen.puts " #{GR}reading the pack…#{LG}"
        files = @gallery.files(pack)
        return unavailable unless files

        loop do
          file = @screen.pick(pack.name, files, empty: 'no text art in this pack.', right: "#{files.size} files") do |f|
            "#{f.name} #{GR}#{f.credits}#{LG}"
          end
          return unless file

          piece(pack, file)
        end
      end

      def piece(pack, file)
        lines = [" #{WH}#{file.title.empty? ? file.name : file.title}#{LG}",
                 " #{CY}#{file.credits}#{LG}", '',
                 " #{GR}file#{LG}  #{file.name}", " #{GR}pack#{LG}  #{pack.name} (#{pack.year})",
                 (" #{GR}date#{LG}  #{file.date}" unless file.date.empty?),
                 (" #{GR}by#{LG}    #{file.artists.join(', ')}" unless file.artists.empty?), '',
                 " #{GR}#{@gallery.file_url(file)}#{LG}"].compact
        @screen.page(file.name, lines, wait: false)
        return if @screen.actions([nil, 'view'], %w[q back]) == 'q'

        @screen.puts " #{GR}fetching…#{LG}"
        art = @gallery.piece(file)
        case art
        when :too_big then return say('This piece is too large for the board.')
        when :unavailable then return say('16colo.rs did not answer. Try again later.')
        end
        show(file, art)
      end

      def show(file, art)
        top   = 0
        left  = 0
        pages = [(art.height + PAGE_ROWS - 1) / PAGE_ROWS, 1].max
        loop do
          draw(file, art, top, left, pages)
          case @screen.key
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

      def draw(file, art, top, left, pages)
        half = " col #{left + 1}" if art.width > HALF
        @screen.title("#{file.name}#{half}", "#{(top / PAGE_ROWS) + 1}/#{pages}")
        pen = Pen.new
        out = +''
        PAGE_ROWS.times do |i|
          cells = art.cells(top + i, left, HALF).map { |c| Pen.art(*c) }
          cells[QUOTE_FROM..].each { |c| c[0] = "'" if c[0] == '"' }
          last = cells.rindex { |ch, _, rvs| ch != ' ' || rvs }
          cells[0..last].each { |c| out << pen.cell(*c) } if last
          next if last == HALF - 1

          out << "\r\n"
          pen.rvs_off!
        end
        @screen.write(out)
        right = art.width > HALF ? "  #{YE}R#{LG} right" : ''
        @screen.write("#{BBS::Ansi::RESET}#{RO} #{YE}ret#{LG} next #{YE}P#{LG} back#{right}  #{YE}Q#{LG} quit")
      end

      def say(text)
        @screen.puts
        @screen.say(text, RD)
        @screen.pause
      end

      def unavailable = say('16colo.rs did not answer. Try again later.')
    end
  end
end
