# frozen_string_literal: true

require 'fileutils'

# The board's library of RFCs: the shelves (the board's own ones of
# config/shelves.yml, the STD, BCP and FYI series, the statuses, the decades
# and the newest), the search, an RFC's record and links, and the RFCs most
# read here. It keeps the index fresh: #refresh downloads and imports it
# when it is older than the TTL. Until the first import the board's own
# shelves still stand, and everything else answers :preparing.
class LibraryService
  SEARCH_LIMIT = 100
  SHELF_LIMIT  = 500
  NEWEST       = 30
  MIN_WORD     = 2
  MAX_WORDS    = 6
  # The words of a search that pick a status (status:standard).
  STATUSES = { 'standard' => 'INTERNET STANDARD', 'std' => 'INTERNET STANDARD', 'proposed' => 'PROPOSED STANDARD',
               'draft' => 'DRAFT STANDARD', 'bcp' => 'BEST CURRENT PRACTICE', 'info' => 'INFORMATIONAL',
               'informational' => 'INFORMATIONAL', 'experimental' => 'EXPERIMENTAL', 'exp' => 'EXPERIMENTAL',
               'historic' => 'HISTORIC', 'unknown' => 'UNKNOWN' }.freeze
  SERIES = { 'STD' => 'Internet Standards: the protocols that are the Internet, each a number that stays',
             'BCP' => 'Best Current Practices: how the Internet is run',
             'FYI' => 'For Your Information: the guides of the 1990s for newcomers' }.freeze

  def initialize(index:, shelves:, reads:, editor:, index_file:, ttl:)
    @index      = index
    @shelves    = shelves
    @reads      = reads
    @editor     = editor
    @index_file = index_file
    @ttl        = ttl
    @importing  = false
    @lock       = Mutex.new
  end

  def ready? = @index.ready?

  # The number of RFCs in the index (0 before the first import).
  def count = @index.count

  # The board's own shelves.
  def own_shelves
    @shelves.all.each_with_index.map do |s, i|
      ShelfModel.new(kind: :curated, key: i, name: s.name, about: s.about, count: s.entries.size)
    end
  end

  # Every shelf: the board's own ones, then (once the index is there) the
  # series, the statuses, the decades and the newest.
  def shelves
    return own_shelves unless ready?

    [*own_shelves, *series_shelves, *status_shelves, *decade_shelves,
     ShelfModel.new(kind: :newest, key: nil, name: 'Newest', about: "The #{NEWEST} RFCs of the highest numbers.",
                    count: NEWEST)]
  end

  # The RFCs of +shelf+ as EntryModels.
  def entries_on(shelf)
    case shelf.kind
    when :curated then curated(@shelves[shelf.key])
    when :series then @index.series(shelf.key).map { |label, rfc| EntryModel.of(rfc, label, :series) }
    when :status then @index.with_status(shelf.key, limit: SHELF_LIMIT).map { |rfc| EntryModel.of(rfc) }
    when :decade then @index.of_decade(shelf.key, limit: SHELF_LIMIT).map { |rfc| EntryModel.of(rfc) }
    else @index.newest(NEWEST).map { |rfc| EntryModel.of(rfc) }
    end
  end

  # What +query+ finds, as EntryModels: an RFC by its number ("854",
  # "rfc 854"), the RFCs of a series ("std 7"), or the RFCs whose title,
  # authors, keywords or abstract have every word, narrowed by
  # status:standard and year:1983. Or why not: :preparing (no index yet),
  # :too_short (no word long enough), [:not_issued, number] or
  # [:unknown, number].
  def search(query)
    return :preparing unless ready?

    if (m = /\A\s*(?:rfc\s*)?(\d{1,5})\s*\z/i.match(query)) then by_number(m[1].to_i)
    elsif (m = /\A\s*(std|bcp|fyi)\s*(\d{1,4})\s*\z/i.match(query))
      @index.series_members(m[1].upcase, m[2]).map { |rfc| EntryModel.of(rfc, "#{m[1].upcase} #{m[2].to_i}", :series) }
    else by_words(query)
    end
  end

  # The index's record of RFC +number+, or nil.
  def rfc(number) = @index.rfc(number)

  # The RFCs +rfc+ is related to, as EntryModels with the relation as the
  # note ("obsoleted by").
  def links(rfc) = @index.relations(rfc.number).map { |kind, other| EntryModel.of(other, kind, :relation) }

  # The relations of +rfc+ by kind: { 'obsoleted by' => [9293], … }.
  def relations(rfc) = @index.relations(rfc.number).group_by(&:first).transform_values { |l| l.map { |_, r| r.number } }

  # The series +rfc+ stands for: ["STD 7"].
  def series_of(rfc) = @index.series_of(rfc.number)

  def reads(rfc) = @reads.count(rfc.number)

  # The +n+ RFCs most read on this board, with the number of reads as the
  # note.
  def most_read(n = 20)
    top = @reads.top(n)
    by_number = @index.rfcs(top.map(&:first)).to_h { |r| [r.number, r] }
    top.filter_map { |number, count| (rfc = by_number[number]) && EntryModel.of(rfc, count, :reads) }
  end

  def stale?
    at = @index.imported_at
    at.nil? || Time.now - at > @ttl
  end

  # Downloads and imports the index when it is stale (or when +force+).
  # Returns :fresh, :busy (an import is running) or :updated. Raises when
  # the site or the import fails; the old index stays then.
  def refresh(force: false)
    return :fresh unless force || stale?
    return :busy unless @lock.synchronize { !@importing && (@importing = true) }

    begin
      import
    ensure
      @lock.synchronize { @importing = false }
    end
  end

  private

  def curated(shelf)
    return [] unless shelf

    known = ready? ? @index.rfcs(shelf.entries.map(&:first)).to_h { |r| [r.number, r] } : {}
    shelf.entries.map { |number, title, note| EntryModel.of(known[number] || RfcModel.stub(number, title), note, :remark) }
  end

  def series_shelves
    SERIES.map do |kind, about|
      ShelfModel.new(kind: :series, key: kind, name: kind, about: about, count: @index.series(kind).size)
    end
  end

  def status_shelves
    @index.statuses.map do |status, n|
      ShelfModel.new(kind: :status, key: status, name: RfcModel.status_label(status), about: "Status: #{status.downcase}.",
                     count: n)
    end
  end

  def decade_shelves
    @index.decades.map do |decade, n|
      ShelfModel.new(kind: :decade, key: decade, name: "#{decade}s", about: "The RFCs of #{decade}-#{decade + 9}.", count: n)
    end
  end

  def by_number(number)
    rfc = @index.rfc(number)
    return [:unknown, number] unless rfc
    return [:not_issued, number] unless rfc.issued?

    [EntryModel.of(rfc)]
  end

  def by_words(query)
    status = STATUSES[query[/(?:\A|\s)status:(\w+)/i, 1].to_s.downcase]
    year   = query[/(?:\A|\s)year:(\d{4})\b/i, 1]&.to_i
    words  = query.gsub(/(?:\A|\s)(?:status|year):\S*/i, ' ').scan(/[\p{L}\p{N}]+/).select { |w| w.length >= MIN_WORD }
    return :too_short if words.empty? && status.nil? && year.nil?

    @index.search(words.first(MAX_WORDS), status: status, year: year, limit: SEARCH_LIMIT).map { |rfc| EntryModel.of(rfc) }
  end

  def import
    started = Time.now
    @editor.download_index(@index_file)
    n = @index.import(@index_file)
    BBS.log('index', format('imported, %<n>d RFCs in %<s>.1f s', n: n, s: Time.now - started))
    GC.start
    :updated
  ensure
    FileUtils.rm_f(@index_file)
  end
end
