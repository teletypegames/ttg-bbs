# frozen_string_literal: true

require 'rexml/parsers/sax2parser'
require 'rexml/sax2listener'

# Reads the RFC Editor's index (rfc-index.xml) as a stream, so the 14 MB
# file never sits in memory as a tree, and yields its entries one by one as
# Hashes:
#
#   { kind: 'rfc-entry', id: 'RFC793', title: '…', authors: [...], month: 'September', year: '1981',
#     pages: '91', status: 'INTERNET STANDARD', abstract: ['…'], keywords: [...],
#     lists: { obsoletes: ['RFC761'], obsoleted_by: ['RFC9293'], is_also: ['STD7'], … } }
#
# +kind+ is the element: rfc-entry, rfc-not-issued-entry, std-entry,
# bcp-entry or fyi-entry. No I/O of its own: the caller gives the IO.
class IndexParser
  ENTRIES = %w[rfc-entry rfc-not-issued-entry std-entry bcp-entry fyi-entry].freeze
  # The lists of document ids in an entry, by element.
  LISTS = { 'obsoletes' => :obsoletes, 'obsoleted-by' => :obsoleted_by, 'updates' => :updates,
            'updated-by' => :updated_by, 'see-also' => :see_also, 'is-also' => :is_also }.freeze
  # The single values of an entry (or of its date), by element.
  FIELDS = { 'title' => :title, 'page-count' => :pages, 'current-status' => :status,
             'publication-status' => :pub_status, 'stream' => :stream, 'area' => :area, 'wg_acronym' => :wg,
             'month' => :month, 'day' => :day, 'year' => :year }.freeze

  # Yields every entry of the index read from +io+.
  def self.each(io, &) = new.parse(io, &)

  def parse(io, &block)
    @stack = []
    @text  = +''
    @entry = nil
    parser = REXML::Parsers::SAX2Parser.new(io)
    parser.listen(:start_element) { |_uri, name, _qname, _attrs| enter(name) }
    parser.listen(:characters) { |text| @text << text }
    parser.listen(:end_element) { |_uri, name, _qname| leave(name, &block) }
    parser.parse
  end

  private

  def enter(name)
    @stack << name
    @text = +''
    @entry = { kind: name, authors: [], keywords: [], abstract: [], lists: Hash.new { |h, k| h[k] = [] } } if
      ENTRIES.include?(name)
  end

  def leave(name)
    @stack.pop
    return unless @entry
    return yield(@entry.tap { @entry = nil }) if ENTRIES.include?(name)

    take(name, @stack.last, squeeze(@text))
  end

  # Puts the text of element +name+ (inside +parent+) into the entry.
  def take(name, parent, text)
    case name
    when 'doc-id' then doc_id(parent, text)
    when 'name' then @entry[:authors] << text if parent == 'author'
    when 'kw' then @entry[:keywords] << text
    when 'p' then @entry[:abstract] << text if parent == 'abstract'
    else field(name, parent, text)
    end
  end

  def doc_id(parent, text)
    if parent == @entry[:kind] then @entry[:id] = text
    elsif LISTS.key?(parent) then @entry[:lists][LISTS[parent]] << text
    end
  end

  # A title of an author ("Editor") is not the entry's.
  def field(name, parent, text)
    key = FIELDS[name] or return
    @entry[key] = text if parent == @entry[:kind] || parent == 'date'
  end

  def squeeze(text) = text.gsub(/\s+/, ' ').strip
end
