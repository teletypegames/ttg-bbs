# frozen_string_literal: true

module UI
  module Petscii
    # The page of one board of Global Discovery on the C64, on a Canvas: the
    # name and address, the state and the last answer, why our server did
    # not reach it, the 30-day strip, the fields, the tags, the lists that
    # name it, the banner note, and the keys. Also the screens of a
    # question (a warning before a dial) and of a message.
    class BoardScreen
      LABEL = 9
      VALUE = Canvas::COLS - 1 - LABEL - 1
      WHY = {
        'dns_fail' => 'NAME DOES NOT RESOLVE', 'timeout' => 'NO ANSWER IN TIME (FIREWALL?)',
        'refused' => 'PORT CLOSED', 'closed' => 'HUNG UP AT ONCE'
      }.freeze

      # A day of the strip: a success a green block, only failures a red dot.
      STRIP = { ::Discovery::BoardPageModel::UP => ['█', Canvas::LIGHT_GREEN],
                ::Discovery::BoardPageModel::DOWN => ['.', Canvas::RED] }.freeze

      def initialize(page, now: Time.now.to_i)
        @page = page
        @now  = now
      end

      def listing = @page.listing

      def frame
        canvas = Canvas.new
        canvas.text(0, 1, listing.title.upcase[0, 38], Canvas::LIGHT_GREEN)
        canvas.text(1, 1, listing.address.upcase[0, 38], Canvas::GREEN)
        mark, color = DiscoveryBoard.mark(listing.state)
        canvas.text(3, 1, mark, color)
        canvas.text(3, 3, listing.state.upcase, color)
        canvas.text(3, 3 + listing.state.length + 2, answer[0, 38 - listing.state.length - 4], Canvas::GREEN)
        canvas.text(4, 3, "FROM US: #{WHY[@page.last_result]}"[0, 36], Canvas::GREY) if why?
        strip(canvas, 5)
        row = 7
        fields.each do |label, value|
          canvas.text(row, 1, label, Canvas::DARK_GREY)
          canvas.text(row, 1 + LABEL, value.to_s.upcase[0, VALUE], Canvas::GREEN)
          row += 1
        end
        tags = listing.tags.reject { |t| t.start_with?('src:', ::Discovery::TagService::CLAIMS) }
        row = wrapped(canvas, row, 'TAGS', tags.join(' '), 2)
        row = wrapped(canvas, row, 'LISTS', @page.source_names.join(', '), 2)
        canvas.text(row, 1, 'BANNER', Canvas::DARK_GREY)
        canvas.text(row, 1 + LABEL, banner_note, Canvas::GREEN)
        keys(canvas)
        canvas.frame
      end

      # Whether there is a banner the C64 can show: a PETSCII one, of the
      # C64-style call or of the scheduled one.
      def banner? = !@page.c64_banner.nil?

      # A question or a message: +lines+ in the middle, +keys+ under them.
      def self.notice(title, lines, keys)
        canvas = Canvas.new
        canvas.text(2, 1, title.upcase[0, 38], Canvas::LIGHT_GREEN)
        lines.each_with_index { |l, i| canvas.text(6 + i, 1, l.upcase[0, 38], Canvas::YELLOW) }
        canvas.text(7 + lines.size, 1, keys, Canvas::GREEN)
        canvas.frame
      end

      private

      def why? = %w[down dead flaky].include?(listing.state) && WHY[@page.last_result]

      def answer
        return 'NOT CALLED YET' unless listing.first_probe_at
        return 'NEVER ANSWERED' unless @page.last_success_at

        "LAST OK #{Time.at(@page.last_success_at).strftime('%Y-%m-%d %H:%M')}"
      end

      def strip(canvas, row)
        canvas.text(row, 1, '30 DAYS', Canvas::DARK_GREY)
        canvas.text(row, 8, '[', Canvas::DARK_GREY)
        @page.strip(@now).each_char.with_index do |day, i|
          glyph, color = STRIP.fetch(day, [' ', nil])
          canvas.text(row, 9 + i, glyph, color)
        end
        canvas.text(row, 9 + ::Discovery::BoardPageModel::STRIP_DAYS, ']', Canvas::DARK_GREY)
      end

      def fields
        shown = @page.fields.reject { |f| f.label == 'Name' }.first(8)
        shown.map { |f| [f.label.upcase.sub('FTN ADDRESS', 'FTN')[0, LABEL - 1], f.value] }
      end

      def wrapped(canvas, row, label, text, lines)
        return row if text.empty?

        canvas.text(row, 1, label, Canvas::DARK_GREY)
        BBS::FrameBuffer.wrap_ansi(text.upcase, VALUE).first(lines).each do |line|
          canvas.text(row, 1 + LABEL, line, Canvas::GREEN)
          row += 1
        end
        row
      end

      def banner_note
        return 'HIDDEN AT THE SYSOP\'S REQUEST' unless listing.preview?
        return 'B SHOWS IT' if banner?
        return 'NONE STORED YET' unless @page.banner

        "#{@page.encoding.to_s.upcase}: MODERN FACE ONLY"
      end

      def keys(canvas)
        canvas.text(22, 1, 'RETURN', Canvas::GREEN)
        canvas.text(22, 7, ' DIAL  ', Canvas::DARK_GREY)
        canvas.text(22, 14, 'B', Canvas::GREEN)
        canvas.text(22, 15, ' BANNER  ', Canvas::DARK_GREY)
        canvas.text(22, 24, 'Q', Canvas::GREEN)
        canvas.text(22, 25, ' BACK', Canvas::DARK_GREY)
        canvas.text(23, 1, 'OPT-OUT: WIKI.TELETYPEGAMES.ORG', Canvas::DARK_GREY)
      end
    end
  end
end
