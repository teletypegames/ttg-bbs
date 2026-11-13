# frozen_string_literal: true

require 'uri'

# The computers and consoles of Wikidata (CC0), read from its SPARQL endpoint with rubbs'
# Rubbs::Common::Web::Wikidata. Wikidata describes a machine as a class (the Commodore 64 is a
# subclass of home computer), so a machine is any item under one of ROOTS by P31 or P279. The
# first queries only gather the items, one a root; the facts then come in BATCH-sized VALUES
# blocks, so no query nears the endpoint's 60 seconds. Any failed query raises
# (Rubbs::Common::Web::HTTP::Error, or Error), so a refresh never leaves half a catalog.
class WikidataRepository
  # Wikidata answered an error status or no JSON.
  Error = Rubbs::Common::Web::Wikidata::Error

  USER_AGENT = 'SiliconiaBBS/0.1 (Siliconia BBS, Teletype Games telnet BBS; https://teletypegames.org; ' \
               'https://git.teletypegames.org/bbs/ttg-bbs/src/branch/master/boards/siliconia)'
  LANGUAGES  = 'en,mul,de,fr,it,es,nl,sv,pl,pt,hu,cs,ru,ja,zh'
  LABELS     = "SERVICE wikibase:label { bd:serviceParam wikibase:language \"#{LANGUAGES}\". }".freeze
  BATCH      = 300

  # The classes a machine is under, the most particular kind first: a handheld is a console too.
  ROOTS = { 'Q941818' => 'handheld', 'Q8076' => 'console', 'Q473708' => 'home', 'Q32738' => 'micro', 'Q16338' => 'pc' }.freeze

  # What an item is when it is no machine: a class of computers, a form factor, a video game,
  # software, a fantasy console, an open-source project, a sequence.
  NOT_MACHINES = %w[Q716676 Q1148887 Q7889 Q7397 Q42342966 Q109860256 Q133250].freeze

  # The list fields of a record and the properties they come from: manufacturer, CPU, operating
  # system, country of origin, follows, followed by.
  PROPERTIES = { 'P176' => 'mak', 'P880' => 'cpu', 'P306' => 'os', 'P495' => 'cty', 'P155' => 'pre', 'P156' => 'suc' }.freeze
  # The fields that hold items of the catalog, not names.
  LINKS = %w[pre suc].freeze

  # The years of a record and the properties they come from: publication, inception (the year
  # when there is no publication), discontinuation.
  DATE_KEYS = { 'P577' => 'y', 'P571' => 'i', 'P2669' => 'e' }.freeze

  # The short names of the units of memory.
  UNITS = {
    'bit'      => 'bit',
    'kilobit'  => 'kbit',
    'byte'     => 'B',
    'kilobyte' => 'kB',
    'kibibyte' => 'KiB',
    'megabyte' => 'MB',
    'mebibyte' => 'MiB',
    'gigabyte' => 'GB',
    'gibibyte' => 'GiB',
    'terabyte' => 'TB',
    'tebibyte' => 'TiB'
  }.freeze

  def initialize(pause: 1, client: Rubbs::Common::Web::Wikidata.new(user_agent: USER_AGENT, pause: pause))
    @client = client
  end

  # The records of every machine, sorted by name.
  def records
    kinds    = machines
    machines = {}
    kinds.keys.each_slice(BATCH) { |ids| batch(ids, kinds, machines) }
    links(machines)
    machines.values.sort_by { |m| [m['t'].downcase, m['id'][1..].to_i] }
  end

  private

  # { id => kind } of every machine under ROOTS.
  def machines
    rows   = ROOTS.keys.to_h { |root| [root, select(items_query(root))] }
    supers = rows.values.flatten.filter_map { |row| qid(row['sup']) }.to_set
    rows.each_with_object({}) do |(root, list), kinds|
      types(list).each { |id, of| kinds[id] ||= ROOTS[root] if machine?(id, of, supers) }
    end
  end

  # { id => the QIDs it is an instance of } of the rows of an items query.
  def types(rows) = rows.group_by { |row| qid(row['item']) }.transform_values { |r| r.filter_map { |row| qid(row['type']) } }

  # Whether +id+, an instance of +of+, is a machine: not a root, nothing of NOT_MACHINES, and not
  # a bare category (no type, and other items are its subclasses).
  def machine?(id, of, supers)
    return false if id.nil? || ROOTS.key?(id) || of.intersect?(NOT_MACHINES)

    !(of.empty? && supers.include?(id))
  end

  def items_query(root)
    <<~SPARQL
      SELECT DISTINCT ?item ?type ?sup WHERE {
        ?item (wdt:P31|wdt:P279)/wdt:P279* wd:#{root} .
        OPTIONAL { ?item wdt:P31 ?type . }
        OPTIONAL { ?item wdt:P279 ?sup . }
      }
    SPARQL
  end

  # Reads the facts of the machines +ids+ into +machines+.
  def batch(ids, kinds, machines)
    values = "VALUES ?item { #{ids.map { |id| "wd:#{id}" }.join(' ')} }"
    names(values, kinds, machines)
    facts(values, machines)
    dates(values, machines)
    quantities(values, machines)
    games(values, machines)
  end

  # The name, the Hungarian name and the Wikipedia articles; a machine Wikidata names in no
  # language is left out.
  def names(values, kinds, machines)
    select(<<~SPARQL).each do |row|
      SELECT ?item ?itemLabel ?hu ?en ?huwiki WHERE {
        #{values}
        OPTIONAL { ?item rdfs:label ?hu . FILTER(LANG(?hu) = "hu") }
        OPTIONAL { ?en schema:about ?item ; schema:isPartOf <https://en.wikipedia.org/> . }
        OPTIONAL { ?huwiki schema:about ?item ; schema:isPartOf <https://hu.wikipedia.org/> . }
        #{LABELS}
      }
    SPARQL
      id   = qid(row['item'])
      name = text(row['itemLabel'])
      named(machines[id] ||= { 'id' => id, 't' => name, 'k' => kinds[id] }, row) if id && named?(name)
    end
  end

  def named?(name) = !name.empty? && !name.match?(/\AQ\d+\z/)

  # The text of a label binding; nil when Wikidata has no name for it.
  def name_of(binding)
    name = text(binding)
    named?(name) ? name : nil
  end

  def named(machine, row)
    hu = text(row['hu'])
    machine['h'] ||= hu unless hu.empty? || hu == machine['t']
    machine['w'] ||= article(row['en'])
    machine['hw'] ||= article(row['huwiki'])
    machine.compact!
  end

  # The lists of PROPERTIES, and the countries of the manufacturers as 'mc'.
  def facts(values, machines)
    select(<<~SPARQL).each { |row| fact(machines, row) }
      SELECT ?item ?p ?v ?vLabel WHERE {
        #{values}
        { VALUES ?p { #{PROPERTIES.keys.map { |p| "wdt:#{p}" }.join(' ')} } ?item ?p ?v . }
        UNION { ?item wdt:P176/wdt:P17 ?v . BIND("mc" AS ?p) }
        #{LABELS}
      }
    SPARQL
    names = PROPERTIES.values + ['mc'] - LINKS
    machines.each_value { |m| names.each { |key| m[key]&.sort_by!(&:downcase) } }
  end

  def fact(machines, row)
    machine = machines[qid(row['item'])]
    p       = row.dig('p', 'value').to_s
    key     = p == 'mc' ? 'mc' : PROPERTIES[p[/P\d+\z/]]
    return unless machine && key

    value = LINKS.include?(key) ? qid(row['v']) : name_of(row['vLabel'])
    return unless value

    list = machine[key] ||= []
    list << value unless list.include?(value)
  end

  # The first year of publication (P577, else of inception, P571) and of discontinuation (P2669).
  def dates(values, machines)
    select(<<~SPARQL).each { |row| date(machines, row) }
      SELECT ?item ?p ?d WHERE { #{values} VALUES ?p { wdt:P577 wdt:P571 wdt:P2669 } ?item ?p ?d . }
    SPARQL
    machines.each_value do |m|
      inception = m.delete('i')
      m['y'] ||= inception if inception
    end
  end

  def date(machines, row)
    machine = machines[qid(row['item'])]
    year    = row.dig('d', 'value').to_s[/\A-?\d{4}/]&.to_i
    key     = DATE_KEYS[row.dig('p', 'value').to_s[/P\d+\z/]]
    return unless machine && key && year&.positive?

    machine[key] = [machine[key], year].compact.min
  end

  # The memory capacities (P2928) with their units, and the units sold (P2664).
  def quantities(values, machines)
    select(<<~SPARQL).each { |row| quantity(machines, row) }
      SELECT ?item ?p ?a ?uLabel WHERE {
        #{values}
        VALUES ?p { p:P2928 p:P2664 }
        ?item ?p ?s .
        ?s ?psv ?node . FILTER(STRSTARTS(STR(?psv), "http://www.wikidata.org/prop/statement/value/"))
        ?node wikibase:quantityAmount ?a .
        OPTIONAL { ?node wikibase:quantityUnit ?u . }
        #{LABELS}
      }
    SPARQL
  end

  def quantity(machines, row)
    machine = machines[qid(row['item'])]
    amount  = number(row.dig('a', 'value'))
    return unless machine && amount&.positive?

    if row.dig('p', 'value').to_s.end_with?('P2664')
      machine['sold'] = [machine['sold'], amount].compact.max
    else
      unit  = text(row['uLabel'])
      shown = "#{amount.to_s.sub(/\.0\z/, '')} #{UNITS.fetch(unit, unit)}".strip
      list  = machine['mem'] ||= []
      list << shown unless list.include?(shown)
    end
  end

  # The number of video games Wikidata knows on each machine (P400).
  def games(values, machines)
    select(<<~SPARQL).each do |row|
      SELECT ?item (COUNT(DISTINCT ?g) AS ?n) WHERE { #{values} ?g wdt:P400 ?item . } GROUP BY ?item
    SPARQL
      machine = machines[qid(row['item'])]
      count   = row.dig('n', 'value').to_i
      machine['g'] = count if machine && count.positive?
    end
  end

  # The predecessors and successors kept only when they are machines of the catalog.
  def links(machines)
    machines.each_value do |m|
      LINKS.each do |key|
        list = Array(m[key]).select { |id| machines.key?(id) && id != m['id'] }
        list.empty? ? m.delete(key) : m[key] = list
      end
    end
  end

  def article(binding)
    url = binding&.dig('value')
    url && text('value' => URI.decode_www_form_component(url.split('/wiki/', 2).last).tr('_', ' '))
  end

  def number(value)
    n = Float(value.to_s.delete_prefix('+'), exception: false)
    n && (n == n.floor ? n.to_i : n.round(2))
  end

  def text(binding) = Rubbs::Common::Web::Wikidata.text(binding)

  def qid(binding) = Rubbs::Common::Web::Wikidata.qid(binding)

  def select(query) = @client.select(query)
end
