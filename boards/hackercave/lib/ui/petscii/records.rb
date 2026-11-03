# frozen_string_literal: true

module UI
  module Petscii
    # The lists of RFCs and an RFC's record on the C64, part of Board: the
    # numbered list, the record on a page, and what to do with it: read it
    # (Reader), its links, its errata, its QR code.
    module Records
      # The most of an abstract a record shows, in characters.
      ABSTRACT = 300

      private

      def entries(heading, list)
        loop do
          entry = @screen.pick(heading, list, empty: 'no rfcs here.', right: "#{list.size} rfcs") { |e| label(e) }
          return unless entry

          record(entry)
        end
      end

      # The number and the title; the reads, the series, the relation, the
      # line it is named on or the year before them.
      def label(entry)
        prefix = case entry.kind
                 when :reads, :year then "#{GR}#{entry.note}#{LG} "
                 when :series then "#{GR}#{entry.note.downcase}#{LG} "
                 when :relation then "#{GR}#{entry.note.split.first}#{LG} "
                 when :line then "#{GR}l.#{entry.note}#{LG} "
                 end
        number = entry.rfc.ien? ? "ien #{entry.rfc.serial}" : entry.number
        "#{prefix}#{number} #{entry.rfc.title.downcase}"
      end

      # An RFC's record, and what to do with it.
      def record(entry)
        rfc = entry.rfc
        loop do
          @screen.page(rfc.name, card(entry), wait: false)
          case @screen.actions(%w[r read], %w[l links], %w[e errata], ['c', 'qr code'], %w[q back])
          when 'r' then open_rfc(rfc)
          when 'l' then links(rfc)
          when 'e' then errata(rfc)
          when 'c' then qr(rfc)
          else return
          end
        end
      end

      def card(entry)
        rfc = entry.rfc
        [*card_head(entry), *lines(@screen.plain(rfc.author_list.first(3).join(', ')), LB), " #{GR}#{facts(rfc)}#{LG}",
         *relation_lines(rfc), *errata_line(rfc), '', *lines(@screen.plain(short(rfc.abstract.split("\n\n").first.to_s)))]
      end

      # The title, and the note of a curated shelf or the line a text search
      # found.
      def card_head(entry)
        [*lines(@screen.plain(entry.rfc.title), WH), *(lines(@screen.plain(entry.note), CY) if entry.kind == :remark),
         *(lines(@screen.plain("found: #{entry.note}"), CY) if entry.kind == :match)]
      end

      # +text+ cut at a word to fit about ABSTRACT characters.
      def short(text) = text.length <= ABSTRACT ? text : "#{text[0, ABSTRACT].sub(/\s+\S*\z/, '')}..."

      def facts(rfc)
        reads = @library.reads(rfc)
        status = rfc.ien? ? 'internet experiment note' : @library.series_of(rfc).first || rfc.status_label
        [rfc.date_label, status, "#{reads} read#{'s' unless reads == 1}"].reject(&:empty?).join(' . ').downcase
      end

      def relation_lines(rfc)
        @library.relations(rfc).flat_map do |kind, numbers|
          lines("#{kind}: #{numbers.first(6).join(', ')}#{' ...' if numbers.size > 6}",
                kind == 'obsoleted by' ? RD : GR)
        end
      end

      def errata_line(rfc)
        count = @library.errata_count(rfc)
        count[:total].zero? ? [] : lines("errata: #{count[:total]} (#{count[:verified]} verified)", OR)
      end

      # +text+ wrapped, each line indented and in +color+.
      def lines(text, color = nil)
        @screen.wrap(text).map { |l| color ? " #{color}#{l}#{LG}" : " #{l}" }
      end

      def links(rfc)
        list = @library.links(rfc)
        return message("#{rfc.name} does not obsolete or update any other.") if list.empty?

        entries("LINKS OF #{rfc.name}", list)
      end

      # The errata, a page each: what the RFC says and what it should say.
      def errata(rfc)
        list = @library.errata(rfc)
        return message("#{rfc.name} has no errata.") if list.empty?

        @screen.page("ERRATA #{rfc.name}", list.flat_map { |e| erratum(e) }, right: "#{list.size} ", numbers: true)
      end

      def erratum(e)
        [" #{OR}#{@screen.plain(["erratum #{e.id}", e.status, e.type, e.section].reject(&:empty?).join(' . ').downcase)}#{LG}",
         " #{GR}it says:#{LG}", *pre(e.orig_text), " #{GR}it should say:#{LG}", *pre(e.correct_text), '']
      end

      # +text+ line by line, each wrapped to the screen.
      def pre(text)
        @screen.plain(text).split("\n").flat_map { |l| l.strip.empty? ? [] : @screen.wrap(l.strip) }.map { |l| " #{l}" }
      end

      def open_rfc(rfc)
        @screen.puts " #{GR}opening #{rfc.name.downcase}...#{LG}"
        doc = @reading.open(rfc, seen: @seen)
        if doc.is_a?(Symbol)
          return message(doc == :no_text ? "The RFC Editor has no plain text of #{rfc.name}." : 'The RFC Editor ' \
            'did not answer. Try again in a minute.')
        end

        Reader.new(@screen, @reading, rfc, doc, on_named: ->(list) { named(rfc, list) }).read
      end

      # The RFCs the reader's RFC names, to open any of them.
      def named(rfc, mentions)
        list = @library.mentioned(mentions)
        return message("#{rfc.name} names no other RFC.") if list.empty?

        entries("NAMED IN #{rfc.name}", list)
      end

      # The RFC's page at the RFC Editor as a QR code, in the middle of the
      # screen.
      def qr(rfc)
        @screen.title(rfc.name, 'scan me ')
        code   = qr_code(rfc.link)
        indent = ' ' * ((COLS - 1 - BBS::FrameBuffer.plain(code.first).size) / 2)
        code.each { |line| @screen.puts("#{indent}#{line}") }
        @screen.pause
      rescue BBS::QR::TooLong
        message("The address is too long for a QR code: #{rfc.url}")
      end

      def qr_code(link)
        BBS::QR.petscii(link)
      rescue BBS::QR::TooLong
        BBS::QR.petscii(link, quiet: 1)
      end
    end
  end
end
