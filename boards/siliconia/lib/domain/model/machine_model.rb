# frozen_string_literal: true

# One computer or console of the catalog, as Wikidata describes it: its QID, name (and Hungarian
# name), kind, the years it came out and was discontinued, the English and Hungarian Wikipedia
# articles, the names of its manufacturers, CPUs, operating systems, countries and memory, the
# units sold, the number of games on it, and the QIDs of the machines before and after it. The
# lists are frozen arrays of frozen strings, shared between machines where they are equal.
MachineModel = Data.define(
  :id,
  :name,
  :name_hu,
  :kind,
  :year,
  :ended,
  :article,
  :article_hu,
  :image,
  :makers,
  :cpus,
  :systems,
  :countries,
  :maker_countries,
  :memory,
  :sold,
  :games,
  :predecessors,
  :successors
) do
  # The machine of a catalog record; nil without an id or a name. +names+ is a Hash that interns
  # the strings shared between machines. Every text is cleaned of control characters: the
  # catalog is Wikidata's, edited by anyone.
  def self.from_record(record, names = {})
    id   = record['id'].to_s
    name = clean(record['t'])
    return nil unless id.match?(/\AQ\d+\z/) && !name.empty?

    new(id: -id, name: -name, **texts(record), **numbers(record), **lists(record, names))
  end

  def self.texts(record)
    {
      name_hu:    text(record['h']),
      kind:       MachineModel::KINDS.key?(record['k']) ? -record['k'] : 'pc',
      article:    text(record['w']),
      article_hu: text(record['hw']),
      image:      text(record['img'])
    }
  end

  def self.numbers(record)
    { year: record['y']&.to_i, ended: record['e']&.to_i, sold: record['sold']&.to_i, games: record['g'].to_i }
  end

  def self.lists(record, names)
    MachineModel::LISTS.to_h do |key, field|
      [key, Array(record[field]).map { |n| names[n.to_s] ||= clean(n).freeze }.reject(&:empty?).uniq.freeze]
    end
  end

  def self.text(value)
    value = clean(value)
    value.empty? ? nil : -value
  end

  def self.clean(text) = Rubbs::Common::Text.clean(text.to_s, keep_newlines: false).strip

  # A name folded for a search: lowercase, no accents, letters and digits only.
  def self.fold(text) = text.to_s.unicode_normalize(:nfkd).downcase.gsub(/[^a-z0-9]/, '')

  def label = year ? "#{name} (#{year})" : name

  # Whether Wikidata says little of it: no article, no maker, no year.
  def sparse? = article.nil? && article_hu.nil? && makers.empty? && year.nil?

  # The countries it comes from, else those of its makers.
  def origin = countries.empty? ? maker_countries : countries

  def hungarian? = (countries + maker_countries).include?('Hungary')

  def kind_name = MachineModel::KINDS.fetch(kind)

  def years
    return nil unless year

    ended && ended != year ? "#{year}–#{ended}" : year.to_s
  end

  def wikidata_url = "https://www.wikidata.org/wiki/#{id}"

  def wikipedia_url = article && "https://en.wikipedia.org/wiki/#{article.tr(' ', '_')}"
end

# The kinds of machines, by the class of Wikidata a machine is under, the most particular first.
MachineModel::KINDS = {
  'handheld' => 'handheld console',
  'console'  => 'video game console',
  'home'     => 'home computer',
  'micro'    => 'microcomputer',
  'pc'       => 'personal computer'
}.freeze

# The list fields and the short keys of a record in the catalog file.
MachineModel::LISTS = {
  makers:          'mak',
  cpus:            'cpu',
  systems:         'os',
  countries:       'cty',
  maker_countries: 'mc',
  memory:          'mem',
  predecessors:    'pre',
  successors:      'suc'
}.freeze
