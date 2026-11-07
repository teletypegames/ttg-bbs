# frozen_string_literal: true

require 'digest'

# The Jargon File (version 4.4.7, public domain): the lexicon by letter, a
# search, an entry and the entries it links to, the word of the day (the
# same for every caller on a day), a random entry, and the other parts to
# read (the introduction, Hacker Folklore, the portrait of J. Random Hacker).
class JargonService
  VERSION = 'Jargon File 4.4.7'
  CREDIT  = "#{VERSION} (public domain)".freeze
  SEARCH_LIMIT = 100
  MIN_WORD     = 2

  # [file] the JargonFileRepository of the File
  def initialize(file:, clock: -> { Time.now }, random: Random.new)
    @file   = file
    @clock  = clock
    @random = random
  end

  # Builds the database from the File when the File changed (or the
  # database is new); :built or :fresh.
  def prepare
    digest = @file.digest
    return :fresh if JargonMetaModel.source == digest

    parsed = @file.parse
    JargonEntryModel.rebuild(parsed.entries, parsed.sections, digest)
    Rubbs.log('jargon', "built: #{parsed.entries.size} entries, #{parsed.sections.size} sections")
    :built
  end

  def ready? = count.positive?

  def count = JargonEntryModel.total

  # [letter, entries]: ["0", 12], ["A", 160], …
  def letters = JargonEntryModel.letters

  def letter(letter) = JargonEntryModel.letter(letter)

  def entry(id)
    Rubbs.achieve(:read, kind: 'jargon', ref: id.to_s)
    JargonEntryModel.entry(id)
  end

  # The entries +entry+ links to that the lexicon has.
  def links(entry) = JargonEntryModel.by_headwords(entry.links)

  # The entries of +query+'s words, or :too_short.
  def search(query)
    words = query.scan(/[\p{L}\p{N}]+/).select { |w| w.length >= MIN_WORD }.first(6)
    return :too_short if words.empty?

    JargonEntryModel.search(words, limit: SEARCH_LIMIT)
  end

  # The entry of today: the same for everyone on a day.
  def word_of_the_day
    n = count
    n.zero? ? nil : entry((Digest::SHA256.hexdigest(@clock.call.strftime('%F'))[0, 12].to_i(16) % n) + 1)
  end

  def random
    n = count
    n.zero? ? nil : entry(@random.rand(n) + 1)
  end

  def sections = JargonSectionModel.in_order
end
