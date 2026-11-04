# frozen_string_literal: true

require 'date'

# The board's library of RFCs: the shelves (the board's own ones of
# config/shelves.yml, the STD, BCP and FYI series, the statuses, the decades,
# this month, the newest and the IENs), the search (the index's, and the
# full text of every RFC through MirrorService), an RFC's record, links and
# errata, and the RFCs most read here. ImportService keeps the index fresh.
# Until the first import the board's own shelves still stand, and everything
# else answers :preparing.
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

  # [shelves] the ShelvesRepository of the board's own shelves
  # [mirror]  the MirrorService of the full-text search, or nil
  def initialize(shelves:, mirror: nil, clock: -> { Time.now })
    @shelves = shelves
    @mirror  = mirror
    @clock   = clock
  end

  def ready? = RfcModel.ready?

  # The number of RFCs in the index (0 before the first import).
  def count = RfcModel.issued_count

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

    [*own_shelves, *series_shelves, *status_shelves, *decade_shelves, month_shelf,
     ShelfModel.new(kind: :newest, key: nil, name: 'Newest', about: "The #{NEWEST} RFCs of the highest numbers.",
                    count: NEWEST), ien_shelf]
  end

  # The RFCs of +shelf+ as EntryModels.
  def entries_on(shelf)
    case shelf.kind
    when :curated then curated(@shelves[shelf.key])
    when :series then SeriesModel.rfcs(shelf.key).map { |label, rfc| EntryModel.of(rfc, label, :series) }
    when :month then RfcModel.of_month(shelf.key, limit: SHELF_LIMIT).map { |rfc| EntryModel.of(rfc, rfc.year, :year) }
    else shelf_rfcs(shelf).map { |rfc| EntryModel.of(rfc) }
    end
  end

  # What +query+ finds, as EntryModels: an RFC by its number ("854",
  # "rfc 854"), an IEN by its ("ien 137"), the RFCs of a series ("std 7"), or the RFCs whose title,
  # authors, keywords or abstract have every word, narrowed by
  # status:standard and year:1983. Or why not: :preparing (no index yet),
  # :too_short (no word long enough), [:not_issued, number] or
  # [:unknown, number].
  def search(query)
    return :preparing unless ready?

    if (m = /\A\s*(?:rfc\s*)?(\d{1,5})\s*\z/i.match(query)) then by_number(m[1].to_i)
    elsif (m = /\A\s*ien\s*(\d{1,3})\s*\z/i.match(query)) then by_number(-m[1].to_i)
    elsif (m = /\A\s*(std|bcp|fyi)\s*(\d{1,4})\s*\z/i.match(query))
      SeriesModel.members_of(m[1].upcase, m[2]).map { |rfc| EntryModel.of(rfc, "#{m[1].upcase} #{m[2].to_i}", :series) }
    else by_words(query)
    end
  end

  # The index's record of RFC +number+, or nil.
  def rfc(number) = RfcModel.rfc(number)

  # The RFCs +rfc+ is related to, as EntryModels with the relation as the
  # note ("obsoleted by").
  def links(rfc) = RelationModel.of(rfc.number).map { |kind, other| EntryModel.of(other, kind, :relation) }

  # The relations of +rfc+ by kind: { 'obsoleted by' => [9293], … }.
  def relations(rfc) = RelationModel.of(rfc.number).group_by(&:first).transform_values { |l| l.map { |_, r| r.number } }

  # The RFCs and IENs of +mentions+ ([number, line index], ReadingService#mentions)
  # that the index has, each with the line it is first named on as the note
  # (:line, from 1).
  def mentioned(mentions)
    by_number = RfcModel.rfcs(mentions.map(&:first)).to_h { |r| [r.number, r] }
    mentions.filter_map { |number, line| (rfc = by_number[number]) && EntryModel.of(rfc, line + 1, :line) }
  end

  # The series +rfc+ stands for: ["STD 7"].
  def series_of(rfc) = SeriesModel.of(rfc.number)

  def reads(rfc) = ReadModel.count_of(rfc.number)

  # The errata of +rfc+ (ErratumModel), the verified ones first.
  def errata(rfc) = ErratumModel.of(rfc.number)

  # How many errata +rfc+ has: { total: 5, verified: 3 }.
  def errata_count(rfc) = ErratumModel.counts(rfc.number)

  # Whether the full text of every RFC can be searched (the mirror is
  # indexed).
  def text_search? = !@mirror.nil? && @mirror.ready?

  # The RFCs whose text has every word of +query+, best matches first, each
  # with the first line that has the first word as the note (:match). Or
  # :preparing (no index, or no mirror yet) or :too_short.
  def search_text(query)
    return :preparing unless ready? && text_search?

    words = query.scan(/[\p{L}\p{N}]+/).select { |w| w.length >= MIN_WORD }.first(MAX_WORDS)
    return :too_short if words.empty?

    hits = @mirror.search(words, limit: SEARCH_LIMIT)
    by_number = RfcModel.rfcs(hits.map(&:first)).to_h { |r| [r.number, r] }
    hits.filter_map { |number, line| (rfc = by_number[number]) && EntryModel.of(rfc, line, :match) }
  end

  # The +n+ RFCs most read on this board, with the number of reads as the
  # note.
  def most_read(n = 20)
    top = ReadModel.top(n)
    by_number = RfcModel.rfcs(top.map(&:first)).to_h { |r| [r.number, r] }
    top.filter_map { |number, count| (rfc = by_number[number]) && EntryModel.of(rfc, count, :reads) }
  end

  private

  def curated(shelf)
    return [] unless shelf

    known = ready? ? RfcModel.rfcs(shelf.entries.map(&:first)).to_h { |r| [r.number, r] } : {}
    shelf.entries.map { |number, title, note| EntryModel.of(known[number] || RfcModel.stub(number, title), note, :remark) }
  end

  def shelf_rfcs(shelf)
    case shelf.kind
    when :status then RfcModel.with_status(shelf.key, limit: SHELF_LIMIT)
    when :decade then RfcModel.of_decade(shelf.key, limit: SHELF_LIMIT)
    when :ien then RfcModel.iens
    else RfcModel.newest(NEWEST)
    end
  end

  def series_shelves
    SERIES.map do |kind, about|
      ShelfModel.new(kind: :series, key: kind, name: kind, about: about, count: SeriesModel.rfcs(kind).size)
    end
  end

  def status_shelves
    RfcModel.statuses.map do |status, n|
      ShelfModel.new(kind: :status, key: status, name: RfcModel.status_label(status), about: "Status: #{status.downcase}.",
                     count: n)
    end
  end

  def decade_shelves
    RfcModel.decades.map do |decade, n|
      ShelfModel.new(kind: :decade, key: decade, name: "#{decade}s", about: "The RFCs of #{decade}-#{decade + 9}.", count: n)
    end
  end

  def month_shelf
    month = @clock.call.month
    name = Date::MONTHNAMES[month]
    ShelfModel.new(kind: :month, key: month, name: "This month: #{name}",
                   about: "The RFCs published in a #{name}, from the first one on.", count: RfcModel.month_count(month))
  end

  def ien_shelf
    ShelfModel.new(kind: :ien, key: nil, name: 'IENs', count: RfcModel.iens.size,
                   about: 'The Internet Experiment Notes of 1977-1982, the working papers of TCP/IP before the RFCs took over.')
  end

  def by_number(number)
    rfc = RfcModel.rfc(number)
    return [:unknown, number] unless rfc
    return [:not_issued, number] unless rfc.issued?

    [EntryModel.of(rfc)]
  end

  def by_words(query)
    status = STATUSES[query[/(?:\A|\s)status:(\w+)/i, 1].to_s.downcase]
    year   = query[/(?:\A|\s)year:(\d{4})\b/i, 1]&.to_i
    words  = query.gsub(/(?:\A|\s)(?:status|year):\S*/i, ' ').scan(/[\p{L}\p{N}]+/).select { |w| w.length >= MIN_WORD }
    return :too_short if words.empty? && status.nil? && year.nil?

    RfcModel.search(words.first(MAX_WORDS), status: status, year: year, limit: SEARCH_LIMIT).map { |rfc| EntryModel.of(rfc) }
  end
end
