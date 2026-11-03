# frozen_string_literal: true

# How the text of an RFC fits a narrow screen. #reflow cuts it into
# paragraphs (lines between blank ones; the running head and foot of a page,
# "RFC 854 … May 1983" and "Postel [Page 3]", are left out, and a paragraph
# broken by a page is joined again) and makes each fit +width+ columns:
#
# - prose (a paragraph of long lines) is joined and wrapped again, its
#   indent shortened, a list item ("o", "*", "1.") with a hanging indent;
# - a figure, a table or code (columns lined up, boxes, dot leaders) and a
#   paragraph of short lines (an address, a list of names) keep their lines;
#   a line longer than +width+ goes on in the next one;
# - a paragraph of one line at the left margin is a heading.
#
# #kinds says the same of the lines as published, for a reader that shows
# them as they are. No I/O.
class ReflowService
  # One line of a reflowed RFC: +kind+ is :heading, :text, :figure, :more (a
  # figure line going on) or :blank.
  Line = Data.define(:text, :kind)

  FOOTER = /\[Page [0-9ivxlcdm]+\]\z/i
  HEADER = /\A(?:RFC \d+\b|.*\b(?:19|20)\d\d\z)/
  FIGURE = /\S {3,}\S|[+|]-|-[+|]|\A\s*[|+]|\|\z|\.{4,}|_{3}|={3}|::=/
  BOX    = /[+|]-|-[+|]|\A\s*[|+]|\|\z/
  LEADER = / ?\.{4,} ?/
  BULLET = /\A((?:[o*+•-]|\d{1,2}[.)]|[a-z][.)]|\([a-z0-9]{1,3}\)))\s+(?=\S)/
  # A prose line is at least this long (with its indent), but for the last
  # of a paragraph.
  PROSE = 55
  SENTENCE_END = /[.:;!?)"]\z/

  # The lines of +doc+ (a DocumentModel) made to fit +width+ columns.
  def reflow(doc, width)
    out = []
    paragraphs(doc).each do |para|
      out << Line.new(text: '', kind: :blank) unless out.empty?
      out.concat(fit(para, width))
    end
    out
  end

  # What each line of +doc+ is, in its order: :page (the running head or
  # foot of a page), :heading or :text.
  def kinds(doc)
    page = page_lines(doc)
    kinds = Array.new(doc.size) { |i| page.include?(i) ? :page : :text }
    blocks(doc, page).each { |b| kinds[b.first] = :heading if b.size == 1 && heading?(doc.lines[b.first]) }
    kinds
  end

  private

  # The paragraphs of +doc+ as arrays of lines, a paragraph broken by a
  # page joined again.
  def paragraphs(doc)
    page = page_lines(doc)
    paras = []
    last = nil
    blocks(doc, page).each do |b|
      lines = b.map { |i| doc.lines[i] }
      if last && (b.first - 1).downto(last + 1).any? { |i| page.include?(i) } && continues?(paras.last, lines)
        paras.last.concat(lines)
      else
        paras << lines
      end
      last = b.last
    end
    paras
  end

  # Whether +lines+, after a page break, go on with the paragraph +before+:
  # it is prose that does not end a sentence, and they are as indented.
  def continues?(before, lines)
    prose?(before + lines) && !SENTENCE_END.match?(before.last) && indent(before.last) == indent(lines.first)
  end

  # The runs of non-blank lines that are not a page's head or foot, as
  # arrays of line indexes.
  def blocks(doc, page)
    blocks = []
    run = []
    doc.lines.each_with_index do |line, i|
      next if page.include?(i)

      if line.strip.empty?
        blocks << run unless run.empty?
        run = []
      else
        run << i
      end
    end
    run.empty? ? blocks : blocks << run
  end

  # The indexes of the lines that are a page's foot ("Postel [Page 3]") or
  # head (the first one to three lines of a page, with the RFC number or a
  # year).
  def page_lines(doc)
    page = Set.new
    doc.lines.each_with_index { |line, i| page << i if FOOTER.match?(line) }
    doc.breaks.each { |b| page.merge(head(doc, b)) }
    page
  end

  # The indexes of the running head of the page that starts at line
  # +start+: its first run of one to three lines, when one of them has the
  # RFC number or a year; none otherwise.
  def head(doc, start)
    first = start
    first += 1 while first < doc.size && doc.lines[first].strip.empty?
    after = first
    after += 1 while after < doc.size && !doc.lines[after].strip.empty?
    run = (first...after).to_a
    run.size.between?(1, 3) && run.any? { |i| HEADER.match?(doc.lines[i].strip) } ? run : []
  end

  def heading?(line) = !line.start_with?(' ') && line.length <= 72 && !FIGURE.match?(line)

  # A paragraph of lines all long enough (but the last), none of them lined
  # up in columns.
  def prose?(lines)
    lines.none? { |l| FIGURE.match?(l.strip) } && lines[0...-1].all? { |l| l.length >= PROSE }
  end

  def fit(lines, width)
    if lines.size == 1 && heading?(lines.first)
      wrap(lines.first, width).map { |l| Line.new(text: l, kind: :heading) }
    elsif prose?(lines) && (lines.size > 1 || lines.first.length > width)
      prose(lines, width)
    else
      kept(lines, width)
    end
  end

  # The paragraph joined and wrapped, a list item with a hanging indent.
  def prose(lines, width)
    lead = short_indent(indent(lines.first))
    text = lines.map(&:strip).join(' ').squeeze(' ')
    m = BULLET.match(text)
    return item(text, m[0], lead, width) if m

    wrap(text, width - lead).map { |l| Line.new(text: "#{' ' * lead}#{l}", kind: :text) }
  end

  # A list item: +bullet+ ("o  ", "1. ") at +lead+, its text after it and
  # under it.
  def item(text, bullet, lead, width)
    hang  = lead + bullet.length
    lines = wrap(text[bullet.length..], width - hang)
    [Line.new(text: "#{' ' * lead}#{bullet}#{lines.first}", kind: :text),
     *lines.drop(1).map { |l| Line.new(text: "#{' ' * hang}#{l}", kind: :text) }]
  end

  # The lines as they are, less their common indent. A box drawing too wide
  # is shown in panels (#panels); in other lines dot leaders get short, and a
  # line still too long breaks where its columns are apart, or anywhere.
  def kept(lines, width)
    common = lines.map { |l| indent(l) }.min
    lines = lines.map { |l| l[common..] }
    return panels(lines, width) if lines.any? { |l| l.length > width } && lines.any? { |l| BOX.match?(l) }

    lines.flat_map { |line| broken(line.gsub(LEADER, ' .. '), width) }
  end

  # A line in pieces of at most +width+: at the gaps between its columns
  # first, each piece wrapped between words, what goes on indented by two.
  def broken(line, width)
    return [Line.new(text: line, kind: :figure)] if line.length <= width

    lead = indent(line)
    lead = 0 if lead > width / 2
    line.strip.split(/(?<=\S) {3,}(?=\S)/).each_with_index.flat_map do |piece, i|
      pad = lead + (i.zero? ? 0 : 2)
      wrap(piece, width - pad - 2).each_with_index.map do |part, j|
        Line.new(text: "#{' ' * (pad + (j.zero? ? 0 : 2))}#{part}", kind: i.zero? && j.zero? ? :figure : :more)
      end
    end
  end

  # A drawing wider than +width+ cut into panels: the first +width+ columns
  # of every line, then the next ones, a line between them saying which
  # columns follow.
  def panels(lines, width)
    wide = lines.map(&:length).max
    (0...wide).step(width).flat_map do |from|
      part = lines.map { |l| Line.new(text: l[from, width].to_s.rstrip, kind: :figure) }
      from.zero? ? part : [Line.new(text: "(columns #{from + 1}-#{[from + width, wide].min})", kind: :more), *part]
    end
  end

  def indent(line) = line[/\A */].size

  # The indent of a narrow screen: none for the RFC's own margin of three,
  # then two and four columns.
  def short_indent(spaces)
    if spaces <= 3 then 0
    elsif spaces <= 6 then 2
    else 4
    end
  end

  # +part+ after +gap+ on the last of +lines+, or on a new line when it
  # does not fit.
  def append(lines, part, gap, width)
    if lines.last.empty? then lines.last << part
    elsif lines.last.length + gap.length + part.length <= width then lines.last << gap << part
    else lines << part.dup
    end
  end

  # +text+ in lines of at most +width+ columns, broken between words, the
  # spaces between the words of a line kept as they were; a word longer
  # than that is broken where it must.
  def wrap(text, width)
    width = [width, 8].max
    lines = [+'']
    text.strip.scan(/(\S+)(\s*)/).each_with_object(['']) do |(word, space), gap|
      word.scan(/.{1,#{width}}/).each do |part|
        append(lines, part, gap[0], width)
        gap[0] = ''
      end
      gap[0] = space
    end
    lines
  end
end
