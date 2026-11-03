# frozen_string_literal: true

# Reads the plain-text Jargon File (jarg447.txt, Latin-1): the lexicon's
# entries (":hack:" lines, their body indented under them) and the other
# parts as sections (the welcome, "Chapter 1. …", "Appendix A. …",
# "Bibliography"). A paragraph of justified prose becomes one line; a
# paragraph indented deeper than the text keeps its lines. No I/O.
class JargonParser
  ENTRY   = /\A:(.+):(?:\s+(\S.*))?\z/
  SECTION = /\A(?:Welcome to the Jargon File|Chapter \d+\. .+|Appendix [A-C]\. .+|Bibliography)\z/
  LEXICON = 'The Jargon Lexicon'
  LETTER  = /\A(?:[A-Z]|0)\z/
  THE_END = /\A#=+ THE JARGON FILE ENDS HERE/
  # The body of the File is indented by this much.
  MARGIN = 3

  attr_reader :entries, :sections

  def initialize(text)
    @entries  = []
    @sections = []
    parse(text.encode(Encoding::UTF_8, Encoding::ISO_8859_1).gsub(/\r\n?/, "\n").lines(chomp: true))
  end

  private

  def parse(lines)
    current = nil
    lines.each do |line|
      current = take(line, current)
      @lexicon = true if line == LEXICON
      @lexicon = false if line.start_with?('Appendix A.')
    end
    finish
  end

  # Reads +line+ into the entry or section open (+current+); the one open
  # after it.
  def take(line, current)
    if (m = ENTRY.match(line)) && @lexicon then start(:entry, m[1].strip, m[2].to_s)
    elsif SECTION.match?(line) then start(:section, line, '')
    elsif boundary?(line) then finish
    else
      current&.fetch(:lines)&.push(line)
      current
    end
  end

  # The start of the lexicon, its end, or a letter's heading in it.
  def boundary?(line) = line == LEXICON || THE_END.match?(line) || (@lexicon && LETTER.match?(line))

  def start(kind, title, rest)
    finish
    @open = { kind: kind, title: title, rest: rest, lines: [] }
  end

  # Ends the entry or section being read; nil.
  def finish
    return @open = nil unless @open

    o = @open
    paragraphs = paragraphs(o[:lines], o[:kind] == :section)
    if o[:kind] == :entry
      @entries << JargonEntryModel.new(id: @entries.size + 1, headword: o[:title], pron: o[:rest], paragraphs: paragraphs)
    else
      @sections << JargonSectionModel.new(id: @sections.size + 1, title: o[:title], paragraphs: paragraphs)
    end
    @open = nil
  end

  def indent(line) = line[/\A */].size

  # The blocks of +lines+ between blank ones, as [kind, text].
  def paragraphs(lines, headings)
    blocks = lines.slice_when { |a, b| a.strip.empty? != b.strip.empty? }.reject { |b| b.first.strip.empty? }
    blocks.map { |block| paragraph(block, headings) }
  end

  # One block as [kind, text]: a heading (a line at the margin of a
  # section), an example (every line indented deeper), or prose.
  def paragraph(block, headings)
    if headings && block.size == 1 && !block.first.start_with?(' ') then [:heading, block.first.strip]
    elsif block.all? { |l| indent(l) > MARGIN }
      common = block.map { |l| indent(l) }.min
      [:pre, block.map { |l| l[common..].rstrip }.join("\n")]
    else [:text, block.map(&:strip).join(' ').squeeze(' ')]
    end
  end
end
