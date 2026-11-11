# frozen_string_literal: true

# A person of the films as their page shows them: the Wikidata id, name,
# description, the years of birth and death, the place of birth, the
# English Wikipedia article, and the films they made (CreditModel), the
# newest first.
PersonModel = Data.define(:id, :name, :description, :born, :died, :birthplace, :enwiki, :credits) do
  # The person of a wbgetentities +entity+, the +birthplace+'s name and
  # their +credits+.
  def self.from_entity(entity, birthplace:, credits:)
    new(
      id:          entity['id'].to_s,
      name:        FilmModel.label(entity, %w[en mul hu]) || entity['id'].to_s,
      description: Rubbs::Common::Text.line(entity.dig('descriptions', 'en', 'value')),
      born:        year(entity, 'P569'),
      died:        year(entity, 'P570'),
      birthplace:  birthplace,
      enwiki:      entity.dig('sitelinks', 'enwiki', 'title'),
      credits:     credits.freeze
    )
  end

  def self.year(entity, property)
    FilmModel.values(entity, property).filter_map { |v| v['time'].to_s[/\A[+-](\d{4})/, 1]&.to_i if v.is_a?(Hash) }.min
  end

  # The id of the place they were born, from +entity+.
  def self.birthplace_id(entity) = FilmModel.ids(entity, 'P19').first

  # "1932–1986", "1956–" while alive, "" when unknown.
  def years
    return '' unless born

    "#{born}–#{died}"
  end

  # "Andrei Tarkovsky (1932–1986)".
  def heading = years.empty? ? name : "#{name} (#{years})"
end

# A film a person made: the film's id, title and year, and their parts in
# it ("director", "cast"…).
CreditModel = Data.define(:id, :title, :year, :parts) do
  # "1979 Stalker".
  def label = [year, title].compact.join(' ')

  def note = parts.join(', ')
end
