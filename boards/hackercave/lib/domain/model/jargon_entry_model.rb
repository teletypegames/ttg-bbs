# frozen_string_literal: true

require 'json'

# One entry of the Jargon File's lexicon (a row of the entries table of
# data/jargon.sqlite3): its id (the order of the file), its headword, its
# key (the headword in lowercase), what follows the headword on its line
# (the pronunciation, "/klooj/"), and its body as paragraphs, each [kind,
# text]: :text (a paragraph on one line) or :pre (lines kept, an example or
# a table). A {word} in the text is a link to the entry of that headword.
# The words are in the FTS5 table entries_fts, under the entry's id.
class JargonEntryModel < BBS::Model
  table :entries, database: :jargon

  # A link in the text.
  LINK = /\{([^{}]+)\}/
  # The first character of the headword, in capitals.
  INITIAL = Sequel.function(:upper, Sequel.function(:substr, :headword, 1, 1))

  # The key a link finds an entry by: the headword in lowercase.
  def self.key(headword) = headword.downcase.gsub(/\s+/, ' ').strip

  # The entry of +id+, or nil.
  def self.entry(id) = guard(nil) { where(id: Integer(id)).first }

  # The entries of these headwords ({links}), in their order; the unknown
  # ones left out.
  def self.by_headwords(headwords)
    keys = headwords.map { |h| key(h) }.uniq
    return [] if keys.empty?

    found = guard([]) { where(key: keys).all }.to_h { |e| [e[:key], e] }
    keys.filter_map { |k| found[k] }
  end

  # The entries whose headword starts with +letter+ (a letter, or "0" for
  # the ones that start with no letter), in the order of the File.
  def self.letter(letter)
    entries = letter == '0' ? exclude(INITIAL => 'A'..'Z') : where(INITIAL => letter)
    guard([]) { entries.order(:id).all }
  end

  # How many entries each letter has: [['0', 12], ['A', 160], …].
  def self.letters
    initial = Sequel.case([[{ INITIAL => 'A'..'Z' }, INITIAL]], '0')
    guard([]) { group_and_count(initial.as(:l)).order(:l).map { |r| [r[:l], r[:count]] } }
  end

  # At most +limit+ entries that have every word of +words+ (a word
  # prefix): the entry whose headword is the words first, then the headword
  # weighing most.
  def self.search(words, limit:)
    terms = words.map { |w| %("#{w.delete('"')}"*) }.join(' ')
    guard([]) do
      select_all(:entries).join(:entries_fts, rowid: :id).where(Sequel.lit('entries_fts MATCH ?', terms))
                          .order(Sequel.desc(Sequel.expr(Sequel[:entries][:key] => key(words.join(' ')))),
                                 Sequel.function(:bm25, :entries_fts, 20.0, 1.0))
                          .limit(limit).all
    end
  end

  # How many entries there are.
  def self.total = guard(0) { count }

  # Puts the File in place of what was there, in one transaction (callers
  # read the old one meanwhile): +entries+ and +sections+ (JargonParser's)
  # and the +digest+ of the file they come from (JargonMetaModel.source).
  def self.rebuild(entries, sections, digest)
    db.transaction do
      Schema::Jargon.create(db)
      entries.each_slice(500) { |slice| insert_all(slice) }
      JargonSectionModel.insert_all(sections)
      JargonMetaModel.source = digest
    end
  end

  # Writes +entries+ (JargonParser's) and their words.
  def self.insert_all(entries)
    rows  = entries.map { |e| [e.id, e.headword, key(e.headword), e.pron, JSON.generate(e.paragraphs)] }
    words = entries.map { |e| [e.id, e.headword, e.paragraphs.map(&:last).join(' ')] }
    import(%i[id headword key pron body], rows)
    db[:entries_fts].import(%i[rowid headword body], words)
  end

  private_class_method :insert_all

  # The value of the block, or +fallback+ when the database fails (logged).
  def self.guard(fallback)
    yield
  rescue Sequel::DatabaseError => e
    BBS.log('jargon', "#{e.class}: #{e.message}")
    fallback
  end

  def pron = self[:pron].to_s

  def paragraphs = @paragraphs ||= JargonSectionModel.paragraphs(self[:body])

  # The headwords the entry links to, in order, each once.
  def links = paragraphs.flat_map { |_, text| text.scan(LINK).flatten }.map { |w| w.gsub(/\s+/, ' ') }.uniq

  # The first paragraph on one line, without the braces of its links.
  def summary = paragraphs.find { |kind, _| kind == :text }&.last.to_s.gsub(LINK, '\1')
end
