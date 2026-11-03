# frozen_string_literal: true

require 'date'

# One RFC of the RFC Editor's index: a row of the rfcs table. +authors+ and
# +keywords+ are joined with "; ", +date+ is "1981-09" or "1990-04-01",
# +abstract+ has its paragraphs separated by an empty line. A number that was
# never issued has +issued+ false and nothing else.
RfcModel = Data.define(:number, :title, :authors, :date, :pages, :status, :pub_status, :stream, :area, :wg,
                       :abstract, :keywords, :issued) do
  # The RFC of an index row, a Hash with the column names as String keys.
  def self.from_row(row)
    texts = %i[title authors date status pub_status stream area wg abstract keywords].to_h { |k| [k, row[k.to_s].to_s] }
    new(number: row['number'], pages: row['pages'].to_i, issued: row['issued'] != 0, **texts)
  end

  # An RFC known only by its number and title (config/shelves.yml), while
  # the index is not there yet.
  def self.stub(number, title = '')
    new(number: number, title: title, authors: '', date: '', pages: 0, status: '', pub_status: '', stream: '',
        area: '', wg: '', abstract: '', keywords: '', issued: true)
  end

  # The status as it is read: "Internet Standard", "Best Current Practice".
  def self.status_label(status) = status.split.map(&:capitalize).join(' ')

  def issued? = issued

  def name = "RFC #{number}"

  def author_list = authors.split('; ').reject(&:empty?)

  def keyword_list = keywords.split('; ').reject(&:empty?)

  def year = date[0, 4].to_s

  # "September 1981", "1 April 1990".
  def date_label
    year, month, day = date.split('-')
    return '' unless year

    [day&.to_i, month && Date::MONTHNAMES[month.to_i], year].compact.join(' ')
  end

  def status_label = self.class.status_label(status)

  def url = "rfc-editor.org/rfc/rfc#{number}"

  # The RFC's page at the RFC Editor, the address of its QR code.
  def link = "https://www.#{url}"
end
