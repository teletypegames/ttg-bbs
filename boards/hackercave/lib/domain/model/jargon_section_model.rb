# frozen_string_literal: true

require 'json'

# A part of the Jargon File that is not the lexicon (a row of the sections
# table of data/jargon.sqlite3): the welcome, a chapter of the
# introduction, an appendix (Hacker Folklore, A Portrait of J. Random
# Hacker, …) or the bibliography. +paragraphs+ as in JargonEntryModel, plus
# :heading for a heading inside it ("The Story of Mel").
class JargonSectionModel < Rubbs::Common::Storage::Model
  table :sections, database: :jargon

  # The paragraphs of a body as stored: [[kind, text]], the kind a Symbol.
  def self.paragraphs(json) = JSON.parse(json.to_s).map { |kind, text| [kind.to_sym, text] }

  # The sections in the order of the File.
  def self.in_order = JargonEntryModel.guard([]) { order(:id).all }

  # Writes +sections+ (JargonParser's).
  def self.insert_all(sections)
    import(%i[id title body], sections.map { |s| [s.id, s.title, JSON.generate(s.paragraphs)] })
  end

  def paragraphs = @paragraphs ||= self.class.paragraphs(self[:body])
end
