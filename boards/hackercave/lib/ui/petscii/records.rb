# frozen_string_literal: true

module UI
  # The lists of RFCs and an RFC's record on the C64: the numbered list, the
  # record on a page, and what to do with it: read it (Reader), its links,
  # its errata, its QR code.
  class Petscii
    # The most of an abstract a record shows, in characters.
    ABSTRACT = 300

    private

    def entries(heading, list)
      each_pick(heading, list, empty: 'no rfcs here.', right: "#{list.size} rfcs", label: method(:entry_label)) do |e|
        record(e)
      end
    end

    # The number and the title; the reads, the series, the relation, the
    # line it is named on or the year before them.
    def entry_label(entry)
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
        page(rfc.name, card(entry), wait: false)
        case actions(%w[r read], %w[l links], %w[e errata], ['c', 'qr code'], %w[q back])
        when 'r' then open_rfc(rfc)
        when 'l' then links(rfc)
        when 'e' then errata(rfc)
        when 'c' then show_qr(rfc)
        else return
        end
      end
    end

    def card(entry)
      rfc = entry.rfc
      [*card_head(entry), *lines(plain(rfc.author_list.first(3).join(', ')), LB), " #{GR}#{facts(rfc)}#{LG}",
       *relation_lines(rfc), *errata_line(rfc), '', *lines(plain(short(rfc.abstract.split("\n\n").first.to_s)))]
    end

    # The title, and the note of a curated shelf or the line a text search
    # found.
    def card_head(entry)
      [*lines(plain(entry.rfc.title), WH), *(lines(plain(entry.note), CY) if entry.kind == :remark),
       *(lines(plain("found: #{entry.note}"), CY) if entry.kind == :match)]
    end

    # +text+ cut at a word to fit about ABSTRACT characters.
    def short(text) = text.length <= ABSTRACT ? text : "#{text[0, ABSTRACT].sub(/\s+\S*\z/, '')}..."

    def facts(rfc)
      reads = library.reads(rfc)
      status = rfc.ien? ? 'internet experiment note' : library.series_of(rfc).first || rfc.status_label
      [rfc.date_label, status, "#{reads} read#{'s' unless reads == 1}"].reject(&:empty?).join(' . ').downcase
    end

    def relation_lines(rfc)
      library.relations(rfc).flat_map do |kind, numbers|
        lines("#{kind}: #{numbers.first(6).join(', ')}#{' ...' if numbers.size > 6}", kind == 'obsoleted by' ? RD : GR)
      end
    end

    def errata_line(rfc)
      count = library.errata_count(rfc)
      count[:total].zero? ? [] : lines("errata: #{count[:total]} (#{count[:verified]} verified)", OR)
    end

    # +text+ wrapped, each line indented and in +color+.
    def lines(text, color = nil)
      wrap(text).map { |l| color ? " #{color}#{l}#{LG}" : " #{l}" }
    end

    def links(rfc)
      list = library.links(rfc)
      return alert("#{rfc.name} does not obsolete or update any other.", color: YE) if list.empty?

      entries("LINKS OF #{rfc.name}", list)
    end

    # The errata, a page each: what the RFC says and what it should say.
    def errata(rfc)
      list = library.errata(rfc)
      return alert("#{rfc.name} has no errata.", color: YE) if list.empty?

      page("ERRATA #{rfc.name}", list.flat_map { |e| erratum(e) }, right: "#{list.size} ", numbers: true)
    end

    def erratum(e)
      [" #{OR}#{plain(["erratum #{e.id}", e.status, e.type, e.section].reject(&:empty?).join(' . ').downcase)}#{LG}",
       " #{GR}it says:#{LG}", *pre(e.orig_text), " #{GR}it should say:#{LG}", *pre(e.correct_text), '']
    end

    # +text+ line by line, each wrapped to the screen.
    def pre(text)
      plain(text).split("\n").flat_map { |l| l.strip.empty? ? [] : wrap(l.strip) }.map { |l| " #{l}" }
    end

    def open_rfc(rfc)
      doc = loading("opening #{rfc.name.downcase}...") { reading.open(rfc, seen: context[:seen] ||= Set.new) }
      if doc.is_a?(Symbol)
        return alert(
          doc == :no_text ? "The RFC Editor has no plain text of #{rfc.name}." : 'The RFC Editor ' \
            'did not answer. Try again in a minute.',
          color: YE
        )
      end

      Reader.new(self, rfc, doc, on_named: ->(list) { named(rfc, list) }).read
    end

    # The RFCs the reader's RFC names, to open any of them.
    def named(rfc, mentions)
      list = library.mentioned(mentions)
      return alert("#{rfc.name} names no other RFC.", color: YE) if list.empty?

      entries("NAMED IN #{rfc.name}", list)
    end

    # The RFC's page at the RFC Editor as a QR code.
    def show_qr(rfc)
      title(rfc.name, 'scan me ')
      pause if qr(rfc.link)
    end
  end
end
