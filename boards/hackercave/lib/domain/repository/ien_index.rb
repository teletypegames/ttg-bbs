# frozen_string_literal: true

# The index of the Internet Experiment Notes (1977-1982) as the RFC Editor
# keeps it, ien-index.txt: a table of fixed columns (number, author, date,
# title), a long title going on in the title column of the next lines, a
# running head and foot on every page. With the IENs the RFC Editor has as
# plain text (+texts+, their numbers, from the listing of its ien/ folder).
# No I/O.
class IenIndex
  # IEN, author, date and title start in these columns.
  COLUMNS = [0, 8, 21, 33].freeze
  ROW = /\A\s{0,3}(\d{1,3})\s{2,}\S/
  MONTHS = %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec].freeze
  Entry = Data.define(:number, :author, :date, :title, :formats)

  attr_reader :entries

  def initialize(text, texts:)
    @texts   = texts.to_set
    @entries = parse(text)
  end

  # The numbers of the IENs in an HTML listing of the ien/ folder that have
  # a .txt file.
  def self.texts_in(listing) = listing.scan(/ien(\d+)\.txt/).flatten.to_set(&:to_i)

  private

  def parse(text)
    rows = []
    text.each_line(chomp: true) do |line|
      if ROW.match?(line) then rows << row(line)
      elsif rows.any? && continuation?(line) then rows.last[:title] << ' ' << line.strip
      end
    end
    rows.map { |r| Entry.new(**r, formats: @texts.include?(r[:number]) ? 'TXT PDF' : 'PDF') }
  end

  # A line of the title column only: the title of the row above goes on.
  def continuation?(line) = line.length > COLUMNS[3] && line[0, COLUMNS[3]].strip.empty? && !line.include?('[page')

  def row(line)
    number = line[/\d+/].to_i
    author = line[COLUMNS[1]...COLUMNS[2]].to_s.strip
    date   = line[COLUMNS[2]...COLUMNS[3]].to_s.strip
    { number: number, author: author.delete('-').strip, date: date(date), title: +line[COLUMNS[3]..].to_s.strip }
  end

  # "29-Jul-77" → "1977-07-29", "Mar-77" → "1977-03", "---" → "".
  def date(text)
    m = /\A(?:(\d{1,2})-)?([A-Z][a-z]{2})-(\d{2})\z/.match(text) or return ''
    month = MONTHS.index(m[2]) or return ''
    ["19#{m[3]}", format('%02d', month + 1), (format('%02d', m[1].to_i) if m[1])].compact.join('-')
  end
end
