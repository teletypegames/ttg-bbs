# frozen_string_literal: true

module UI
  # What both faces tell the caller: a machine's facts, and the words for the answers of the
  # services.
  module Wording
    TAGLINE = 'the museum of computers and consoles'

    ABOUT = 'Siliconia BBS — the computer and console museum of Teletype Games: every home computer, ' \
            'microcomputer, personal computer and video game console Wikidata knows, with its maker, years, ' \
            'CPU and memory, its family line and the Wikipedia story. Mark the machines you had, and write ' \
            'down what you remember of them.'

    SOURCES = 'The machines and their facts come from Wikidata (wikidata.org), under CC0, refreshed every week: ' \
              'every item under home computer, microcomputer, personal computer or video game console. ' \
              'Wikidata is edited by anyone, so a fact may be missing (shown as a dash) or wrong; fix it there ' \
              'and it shows here. The stories are the leads of the English and Hungarian Wikipedia articles, ' \
              'under CC BY-SA 4.0. The memories are written by callers and read by an admin before they show.'

    MISSING = '—'

    # The facts shown even when Wikidata has none.
    CORE = %w[Years Maker CPU Memory].freeze

    MARKS = { 'owned' => 'I had one', 'grew_up' => 'I grew up on it' }.freeze

    # What becomes of a memory a caller sends (MemoryService#submit).
    MEMORY = {
      ok:           'Thanks! Your memory waits for an admin, and shows once approved.',
      account:      'A memory goes under your name: log in or make an account first (your profile).',
      empty:        'Write the memory first.',
      too_long:     "A memory is at most #{MemoryService::MAX_TEXT} characters.",
      rate_limited: "That is enough memories for now: #{MemoryService::PER_CALLER} an hour, one every " \
                    "#{MemoryService::GAP} seconds.",
      failed:       'The memory could not be saved. Try again later.'
    }.freeze

    MEMORY_RULES = 'What do you remember of it? The first time you saw one, the games, the manuals, the ' \
                   "smell of the box. Up to #{MemoryService::MAX_TEXT} characters; an admin reads it first.".freeze

    ACCOUNT = 'Your machines go under your name: log in or make an account first (your profile).'

    # Where the network has more of a machine.
    ELSEWHERE = {
      'Q99775'   => 'its games on Commodex BBS, downloads on WarpEngine BBS',
      'Q868568'  => 'downloads on WarpEngine BBS',
      'Q1115913' => 'downloads on WarpEngine BBS'
    }.freeze

    # The facts of +machine+ as [label, text] pairs: the CORE ones always (a dash when Wikidata has
    # none), the others only when known. +catalog+ names the machines before and after it.
    def self.facts(machine, catalog)
      (hardware(machine) + history(machine, catalog)).filter_map do |label, value|
        text = Array(value).join(', ')
        text = MISSING if text.empty? && CORE.include?(label)
        [label, text] unless text.empty?
      end
    end

    def self.hardware(machine)
      [['Kind', machine.kind_name], ['Years', machine.years], ['Maker', machine.makers], ['Origin', machine.origin],
       ['CPU', machine.cpus], ['Memory', machine.memory], ['System', machine.systems]]
    end

    def self.history(machine, catalog)
      [['Sold', sold(machine.sold)], ['Games', games(machine.games)], ['Before', catalog.predecessors(machine).map(&:name)],
       ['After', catalog.successors(machine).map(&:name)], ['Magyarul', machine.name_hu], ['See also', ELSEWHERE[machine.id]]]
    end

    # Two machines side by side: [label, first, second], a dash where one has none.
    def self.compare(first, second, catalog)
      a = facts(first, catalog).to_h
      b = facts(second, catalog).to_h
      (a.keys | b.keys).reject { |k| k == 'See also' }.map { |k| [k, a.fetch(k, MISSING), b.fetch(k, MISSING)] }
    end

    def self.edit_hint(machine) = "Missing or wrong? Edit it on Wikidata: #{machine.id}"

    def self.sold(count) = count&.positive? ? "#{count.to_s.reverse.scan(/\d{1,3}/).join(',').reverse} units" : nil

    def self.games(count) = count.positive? ? "#{count} on Wikidata" : nil

    def self.marks(counts)
      "#{counts['owned']} had one, #{counts['grew_up']} grew up on it"
    end

    def self.memories(count)
      if count.zero?
        'no memories yet'
      else
        "#{count} memor#{count == 1 ? 'y' : 'ies'}"
      end
    end

    def self.decade(decade) = "#{decade}s"

    def self.search(result, query)
      case result
      when :too_short then "Type at least #{CatalogService::MIN_QUERY} letters or digits."
      when [] then "No machine, maker or CPU holds \"#{query}\"."
      end
    end

    def self.about(result, language)
      case result
      when :no_article then "Wikipedia has no #{language == 'hu' ? 'Hungarian' : 'English'} article on this machine."
      when :unavailable then 'Wikipedia did not answer. Try again later.'
      end
    end

    def self.mark(result, kind)
      case result
      when :added then "Marked: #{MARKS[kind].downcase}."
      when :removed then "Mark taken back: #{MARKS[kind].downcase}."
      else ACCOUNT
      end
    end
  end
end
