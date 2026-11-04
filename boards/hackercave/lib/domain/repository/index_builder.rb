# frozen_string_literal: true

require 'json'

# Builds the index (RfcModel, RelationModel, SeriesModel, ErratumModel)
# anew from the RFC Editor's rfc-index.xml, read as a stream by
# IndexParser: the RFCs and the numbers never issued, their relations, the
# STD, BCP and FYI series, and the full-text index (FTS5 where the SQLite
# has it, a search column for LIKE where not). The errata (errata.json) and
# the IENs (an IenIndex, under negative numbers) go in too when given. The
# rows go to the models in slices of SLICE.
class IndexBuilder
  SERIES = %w[STD BCP FYI].freeze
  MONTHS = %w[January February March April May June July August September October November December].freeze
  SLICE = 500

  # Builds the index from +xml+, with the +errata+ (the path of
  # errata.json) and the +iens+ (an IenIndex) when given, in place of the
  # old one (RfcModel.rebuild: in one transaction, so callers read the old
  # one meanwhile). Returns the number of RFCs issued. Raises what reading
  # the files raises; the old index stays then.
  def build(xml, errata: nil, iens: nil)
    RfcModel.rebuild do |fts|
      @fts  = fts
      @rows = { RfcModel => [], RelationModel => [], SeriesModel => [], ErratumModel => [] }
      n = 0
      File.open(xml) { |io| IndexParser.each(io) { |entry| n += insert(entry) } }
      add_iens(iens) if iens
      add_errata(errata) if errata
      flush
      n
    end
  end

  private

  # One entry; 1 when it is an RFC issued, else 0.
  def insert(entry)
    kind, number = doc_id(entry[:id])
    return 0 unless number

    if SERIES.include?(kind) then add_series(kind, number, entry)
    elsif entry[:kind] == 'rfc-not-issued-entry' then add_missing(number)
    else return add_rfc(number, entry)
    end
    0
  end

  def add_series(kind, number, entry)
    entry[:lists][:is_also].each do |id|
      member_kind, member = doc_id(id)
      add(SeriesModel, [kind, number, member]) if member_kind == 'RFC'
    end
  end

  def add_missing(number) = add(RfcModel, [number, *([nil] * 13), 0, nil])

  # The RFC and its relations; 1.
  def add_rfc(number, entry)
    add(RfcModel, [*row(number, entry), @fts ? nil : search_text(entry)])
    RelationModel::RELATIONS.each_key do |kind|
      entry[:lists][kind.to_sym].each do |id|
        target_kind, target = doc_id(id)
        add(RelationModel, [number, kind, target]) if target_kind == 'RFC'
      end
    end
    1
  end

  def row(number, entry)
    [number, entry[:title].to_s, entry[:authors].join('; '), date(entry), entry[:year].to_i, entry[:pages].to_i,
     entry[:status].to_s, entry[:pub_status].to_s, entry[:stream].to_s, entry[:area].to_s, entry[:wg].to_s,
     entry[:abstract].join("\n\n"), entry[:keywords].join('; '), entry[:formats].join(' '), 1]
  end

  # The IENs of +iens+ under negative numbers, as Internet Experiment Notes
  # of the stream "IEN".
  def add_iens(iens)
    iens.entries.each do |e|
      add(RfcModel, [-e.number, e.title, e.author, e.date, e.date[0, 4].to_i, 0, '', '', 'IEN', '', '', '', '',
                     e.formats, 1, @fts ? nil : "#{e.title} #{e.author}".downcase])
    end
  end

  # The errata of errata.json; the RFCs only.
  def add_errata(path)
    JSON.parse(File.read(path)).each do |e|
      kind, number = doc_id(e['doc-id'])
      next unless kind == 'RFC' && (id = Integer(e['errata_id'], exception: false))

      add(ErratumModel, [id, number, *%w[errata_status_code errata_type_code section orig_text correct_text notes submit_date]
        .map { |k| errata_text(e[k]) }])
    end
  end

  # Keeps +row+ for +model+, written with the next SLICE.
  def add(model, row)
    rows = @rows.fetch(model)
    rows << row
    return if rows.size < SLICE

    model.insert_rows(rows)
    rows.clear
  end

  # Writes the rows kept.
  def flush
    @rows.each { |model, rows| model.insert_rows(rows) unless rows.empty? }
  end

  # A field of an erratum without control characters, its tabs as spaces.
  def errata_text(value)
    BBS::Text.clean(value.to_s, keep_newlines: true).split("\n").map { |l| DocumentModel.expand(l) }.join("\n")
  end

  # "1981-09", or "1990-04-01" when the index has the day.
  def date(entry)
    month = MONTHS.index(entry[:month].to_s)
    return entry[:year].to_s unless month

    [entry[:year], format('%02d', month + 1), (format('%02d', entry[:day].to_i) if entry[:day])].compact.join('-')
  end

  # "RFC0793" → ["RFC", 793]; nil for anything else.
  def doc_id(id)
    m = /\A(RFC|STD|BCP|FYI)0*(\d+)\z/.match(id.to_s) or return nil
    [m[1], m[2].to_i]
  end

  def search_text(entry) = [entry[:title], *entry[:authors], *entry[:keywords], *entry[:abstract]].join(' ').downcase
end
