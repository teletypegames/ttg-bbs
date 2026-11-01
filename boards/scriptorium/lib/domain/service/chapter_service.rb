# frozen_string_literal: true

# How a Project Gutenberg plain text becomes something to read on a
# terminal. #clean takes off the licence header and footer, evens out the
# line ends and joins the hard-wrapped lines of a paragraph (verse, lists and
# tables of contents keep their lines). #cut finds the chapters by their
# headings and gives their byte ranges; a book without headings is cut into
# sections of about the same size. No I/O: the text comes in and goes out as
# a String.
class ChapterService
  START_RE = /^\*{3}\s*START OF (?:THE|THIS) PROJECT GUTENBERG.*$/i
  END_RE   = /^\*{3}\s*END OF (?:THE|THIS) PROJECT GUTENBERG/i
  # Older texts end with the licence after a line like this.
  OLD_END_RE = /^\s*End of (?:the )?Project Gutenberg'?s? /i

  KEYWORDS = %w[chapter book part act scene stave letter canto volume section capítulo capitulo chapitre livre
                kapitel buch teil libro parte tratado].flat_map { |w| [w.upcase, w.capitalize] }
  NUMBER_WORDS = %w[one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen
                    seventeen eighteen nineteen twenty first second third fourth fifth sixth seventh eighth ninth
                    tenth eleventh twelfth last].freeze
  NUMBER = "(?:[IVXLCDM]{1,7}|[ivxlc]{1,7}|\\d{1,4}|(?i:(?:the\\s+)?(?:#{NUMBER_WORDS.join('|')})))".freeze
  HEADING_RES = [
    /\A(?:#{KEYWORDS.join('|')})\s+#{NUMBER}(?![\p{L}\d])\.?(?:[\s:.,\-—–]+.{0,60})?\z/,
    /\A(?:PREFACE|PROLOGUE|EPILOGUE|INTRODUCTION|CONCLUSION|APPENDIX|FINALE|AFTERWORD|FOREWORD)\b[^a-z]{0,50}\z/,
    /\A(?:Preface|Prologue|Epilogue|Introduction|Conclusion|Appendix|Afterword|Foreword)\.?\z/,
    /\A[IVXLC]{1,7}\.?\z/,
    /\A[IVXLC]{1,7}\.\s+[A-Z][^a-z]{2,60}\z/
  ].freeze

  # A chapter whose text is shorter than this is a heading of the next one
  # ("BOOK I" right above "CHAPTER I") or an entry of a table of contents.
  SHORT = 200
  # A paragraph block of more lines than this has no blank lines in it: it
  # is cut where a short line ends a paragraph.
  LONG_BLOCK = 40

  # [chapter_max] a chapter longer than this many bytes is read in parts
  # [section]     the size of a section of a book without headings
  def initialize(chapter_max: 40_000, section: 16_000)
    @chapter_max = chapter_max
    @section     = section
  end

  # The readable text of +raw+ (the bytes of a pg<N>.txt): UTF-8, LF line
  # ends, paragraphs separated by one empty line, a prose paragraph on one
  # line.
  def clean(raw)
    text = utf8(raw).delete_prefix('﻿').gsub(/\r\n?/, "\n").tr("\t", ' ')
    text = body(text)
    blocks = text.split(/\n[ \t]*\n+/).flat_map { |b| split_long(b.split("\n").map(&:rstrip).reject(&:empty?)) }
    blocks.filter_map { |lines| reflow(lines) }.join("\n\n")
  end

  # The chapters of a #clean text as [title, byte offset, byte length].
  def cut(text)
    paras = paragraphs(text)
    return [] if paras.empty?

    heads = headings(paras)
    chapters = heads.size >= 2 ? by_headings(paras, heads, text.bytesize) : sections(paras, text.bytesize)
    chapters.flat_map { |c| split_big(paras, *c) }
  end

  private

  def utf8(raw)
    s = raw.dup.force_encoding(Encoding::UTF_8)
    return s if s.valid_encoding?

    raw.dup.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8)
  end

  def body(text)
    if (m = START_RE.match(text))
      text = text[m.end(0)..]
    end
    if (m = END_RE.match(text) || OLD_END_RE.match(text))
      text = text[0...m.begin(0)]
    end
    text
  end

  # A block without blank lines in it, cut where a short line ends a
  # paragraph.
  def split_long(lines)
    return [lines] if lines.size <= LONG_BLOCK

    lines.slice_after { |l| l.strip.length < 50 }.to_a
  end

  # One paragraph: prose joined to one line, verse and lists (short lines)
  # kept line by line without their common indent. Italics marked _so_ lose
  # the underscores.
  def reflow(lines)
    return nil if lines.empty?

    lines = lines.map { |l| l.gsub(/_(\S(?:[^_]*\S)?)_/, '\1') }
    return lines.first.strip.squeeze(' ') if lines.size == 1

    if prose?(lines)
      lines.map(&:strip).join(' ').squeeze(' ')
    else
      indent = lines.map { |l| l[/\A */].size }.min
      lines.map { |l| l[indent..] }.join("\n")
    end
  end

  # Hard-wrapped prose has a ragged but even right edge: every line but the
  # last nearly as long as the longest. Verse and lists have short lines of
  # any length, every one starting with a capital.
  def prose?(lines)
    lengths = lines.map { |l| l.strip.length }
    wide    = lengths.max
    return false if wide < 40
    return false if lines.size >= 3 && lines.all? { |l| l.strip.match?(/\A[“"‘'(]?\p{Lu}/) } && lengths.sum / lines.size < 50

    body = lengths[0..-2]
    body.count { |n| n >= wide * 0.75 } >= body.size * 0.75
  end

  # [byte offset, text] of every paragraph.
  def paragraphs(text)
    pos = 0
    text.split("\n\n").map do |p|
      para = [pos, p]
      pos += p.bytesize + 2
      para
    end
  end

  # The title of +para+ when it is a chapter heading, else nil.
  def heading(para)
    lines = para.split("\n").map(&:strip)
    return nil if lines.size > 2 || lines.any? { |l| l.length > 70 }

    first = lines.first.delete_prefix('[').delete_suffix(']').strip
    return nil unless HEADING_RES.any? { |re| re.match?(first) }

    parts = [first, *lines.drop(1).map { |l| l.delete_suffix(']') }].map { |l| l.squeeze(' ').sub(/[.:]\z/, '') }
    parts.reject(&:empty?).join(' — ')[0, 60]
  end

  # The headings that start a chapter, as [paragraph index, title]: the
  # entries of a table of contents (a short heading whose title comes again
  # later) are left out, and a short one is put on top of the next.
  def headings(paras)
    heads = paras.each_with_index.filter_map { |(_, p), i| (t = heading(p)) && [i, t] }
    sizes = heads.each_with_index.map { |(i, _), k| body_size(paras, i, heads[k + 1]&.first) }
    later = Hash.new(0)
    heads.each { |head| later[key(head[1])] += 1 }
    kept = heads.zip(sizes).filter_map do |(i, t), size|
      later[key(t)] -= 1
      next if size < SHORT && later[key(t)].positive?

      [i, t, size]
    end
    merge_short(kept)
  end

  def key(title) = title.upcase.gsub(/[^\p{L}\p{N}]+/, ' ').strip

  def body_size(paras, from, to)
    to ||= paras.size
    paras[(from + 1)...to].sum { |_, p| p.bytesize + 2 }
  end

  def merge_short(heads)
    out = []
    pending = nil
    heads.each_with_index do |(i, t, size), k|
      if pending
        i = pending[0]
        t = "#{pending[1]} · #{t}"[0, 60]
        pending = nil
      end
      if size < SHORT && k < heads.size - 1
        pending = [i, t]
      else
        out << [i, t]
      end
    end
    out << pending if pending
    out
  end

  # [title, from, to] byte ranges; the text before the first heading is an
  # opening chapter of its own when there is enough of it.
  def by_headings(paras, heads, total)
    first = paras[heads.first.first].first
    chapters = heads.each_with_index.map do |(i, t), k|
      to = heads[k + 1] ? paras[heads[k + 1].first].first : total
      [t, paras[i].first, to]
    end
    if first >= SHORT * 2
      chapters.unshift(['Opening pages', 0, first])
    else
      chapters.first[1] = 0
    end
    chapters.map { |t, from, to| [t, from, to - from] }
  end

  def sections(paras, total)
    cuts = chunk(paras, 0, total, @section)
    cuts.each_with_index.map { |(from, length), k| ["Part #{k + 1}/#{cuts.size}", from, length] }
  end

  # A chapter longer than the limit, in parts of about the same size.
  def split_big(paras, title, from, length)
    return [[title, from, length]] if length <= @chapter_max

    parts = (length.to_f / @chapter_max).ceil
    cuts  = chunk(paras, from, from + length, (length.to_f / parts).ceil)
    return [[title, from, length]] if cuts.size < 2

    cuts.each_with_index.map { |(f, l), k| ["#{title} (#{k + 1}/#{cuts.size})"[0, 66], f, l] }
  end

  # [offset, length] pieces of the bytes from +from+ to +to+, cut at the
  # paragraph boundaries nearest after every +size+ bytes.
  def chunk(paras, from, to, size)
    starts = [from]
    paras.map(&:first).each do |off|
      next if off <= from || off >= to

      starts << off if off - starts.last >= size
    end
    starts << to
    pieces = starts.each_cons(2).map { |a, b| [a, b - a] }
    if pieces.size > 1 && pieces.last[1] < size / 4
      last = pieces.pop
      pieces[-1] = [pieces[-1][0], pieces[-1][1] + last[1]]
    end
    pieces
  end
end
