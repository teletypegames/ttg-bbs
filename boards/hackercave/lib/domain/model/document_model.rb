# frozen_string_literal: true

# The text of an RFC as the RFC Editor published it, in lines: +lines+
# without their line ends, form feeds and control characters, tabs as
# spaces; +breaks+ the indexes of the lines a new page of the RFC starts at
# (after a form feed; the RFCs since 8650 have no pages).
DocumentModel = Data.define(:number, :lines, :breaks) do
  # The document of +text+ (UTF-8): a form feed ends a page.
  def self.parse(number, text)
    lines  = []
    breaks = []
    text.delete_prefix("\uFEFF").gsub(/\r\n?/, "\n").split("\n").each do |line|
      breaks << lines.size if line.include?("\f") && !lines.empty? && breaks.last != lines.size
      lines << clean(line)
    end
    lines.pop while lines.last&.empty?
    new(number: number, lines: lines.freeze, breaks: breaks.select { |b| b < lines.size }.freeze)
  end

  # +line+ without form feeds and control characters, its tabs as spaces,
  # no spaces at its end.
  def self.clean(line) = expand(line.delete("\f")).rstrip.gsub(BBS::Text::CONTROLS, '')

  # +line+ with its tabs as spaces to the next multiple of 8.
  def self.expand(line)
    return line unless line.include?("\t")

    line.each_char.with_object(+'') { |c, out| out << (c == "\t" ? ' ' * (8 - (out.size % 8)) : c) }
  end

  def size = lines.size

  def paged? = !breaks.empty?

  # The RFC's pages; 1 when it has none.
  def pages = breaks.size + 1

  # The page of the RFC line +index+ is on, from 1.
  def page_of(index) = breaks.count { |b| b <= index } + 1
end
