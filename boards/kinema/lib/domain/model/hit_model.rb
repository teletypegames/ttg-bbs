# frozen_string_literal: true

# One hit of a search, a film or a person: the Wikidata id, the name and
# Wikidata's one-line description ("1979 film by Andrei Tarkovsky").
HitModel = Data.define(:id, :label, :note) do
  # The hit of a search answer's page (generator=search, prop=entityterms),
  # named +name+ when given (the English label is not always there: some
  # items keep their name in the "mul" label).
  def self.from_api(page, name = nil)
    terms = page['entityterms'] || {}
    new(
      id:    page['title'].to_s,
      label: Rubbs::Common::Text.line(name || Array(terms['label']).first || page['title']),
      note:  Rubbs::Common::Text.line(Array(terms['description']).first)
    )
  end

  # A catalog film as a hit, when Wikidata's search did not answer.
  def self.from_catalog(film) = new(id: film.id, label: film.label, note: film.note)
end
