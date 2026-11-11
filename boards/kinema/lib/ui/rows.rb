# frozen_string_literal: true

module UI
  # One row of a list of films or people, whatever it came from: the
  # Wikidata id, the label, a note, and whether it is a person.
  Row = Data.define(:id, :label, :note, :person) do
    def initialize(id:, label:, note: '', person: false) = super

    def person? = person
  end

  # The lists both faces show, as Rows.
  module Rows
    module_function

    def films(list) = list.map { |f| Row.new(id: f.id, label: f.label, note: f.note) }

    def hits(list, person: false) = list.map { |h| Row.new(id: h.id, label: h.label, note: h.note, person: person) }

    def marks(list) = list.map { |m| Row.new(id: m.film_id, label: m.label, note: "added #{m.created_at.to_s[0, 10]}") }

    def ratings(list) = list.map { |r| Row.new(id: r.film_id, label: r.label, note: "#{r.stars}/10 · #{r.date}") }

    def top(list)
      list.map { |id, title, year, average, count|
        Row.new(id: id, label: [year, title].compact.join(' '), note: Wording.score(average, count))
      }
    end

    def credits(person) = person.credits.map { |c| Row.new(id: c.id, label: c.label, note: c.note) }

    # A film's people: one row a person, with their parts in it.
    def people(film)
      film.credits.group_by { |_, person| person }.map do |person, parts|
        Row.new(id: person.id, label: person.name, note: parts.map(&:first).uniq.join(', '), person: true)
      end
    end
  end
end
