# frozen_string_literal: true

module Discovery
  # What a caller typed into the search of the Gate (TTG_DISCOVERY.md §7): the
  # words that are tags ("petscii hu online": the encoding, cc:hu and the
  # state, all three must hold), the rest free text for the full-text index
  # (name, sysop, location, software, host; every word must match the start
  # of a word), and +all+, which lets the dead boards in.
  #
  # A word is a tag when it is one of the fixed tags (the encodings, the
  # states, new, veteran, the telnet options), or a tag with its prefix
  # (cc:hu, claims:petscii), or when a board has the tag cc:, sw:, net: or
  # src: with it (hu, synchronet, fidonet, sbl).
  class SearchQuery < Data.define(:text, :tags, :words, :all)
    FIXED    = %w[ansi petscii atascii ascii online flaky down dead new veteran binary naws ttype].freeze
    PREFIXES = %w[cc sw net src claims].freeze
    ALL      = 'all'

    # +text+ read against +vocabulary+, the tags the catalog has (a Set or an
    # Array).
    def self.parse(text, vocabulary = [])
      tags  = []
      words = []
      all   = false
      text.to_s.downcase.split.each do |token|
        word = token.gsub(/[^[:alnum:]:_.-]/, '').gsub(/\A[-:._]+|[-:._]+\z/, '')
        next unless word.match?(/[[:alnum:]]/)
        next all = true if word == ALL

        tag = tag(word, vocabulary)
        tag ? tags << tag : words << word
      end
      new(text: text.to_s.strip, tags: tags.uniq.freeze, words: words.uniq.freeze, all: all)
    end

    def self.tag(word, vocabulary)
      return word if FIXED.include?(word)
      return word if PREFIXES.any? { |p| word.start_with?("#{p}:") } && word.length > word.index(':') + 1

      PREFIXES.map { |p| "#{p}:#{word}" }.find { |t| vocabulary.include?(t) }
    end

    def empty? = tags.empty? && words.empty? && !all

    # Whether the dead boards belong in the result: +all+, or the tag dead.
    def all? = all || tags.include?('dead')

    # The FTS5 query of the free words: each a quoted prefix, all of them
    # needed; nil without words.
    def match
      return if words.empty?

      words.map { |w| %("#{w.delete('"')}"*) }.join(' ')
    end
  end
end
