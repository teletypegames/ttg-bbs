# frozen_string_literal: true

# One erratum of an RFC from the RFC Editor's errata.json (a row of the
# errata table of data/index.sqlite3): its id, the RFC, its status
# ("Verified", "Reported", "Held for Document Update", "Rejected"), its type
# ("Technical", "Editorial"), the section, the text as published and as it
# should read, the notes, and the day it was reported.
class ErratumModel < Rubbs::Common::Storage::Model
  table :errata, database: :index

  ROW = %i[id rfc status type section orig_text correct_text notes submitted].freeze
  TEXTS = %i[status type section orig_text correct_text notes submitted].freeze

  TEXTS.each { |column| define_method(column) { self[column].to_s } }

  # The errata of RFC +number+, the verified ones first, then by id.
  def self.of(number)
    RfcModel.guard([]) { where(rfc: Integer(number)).order(Sequel.~(status: 'Verified'), :id).all }
  end

  # How many errata RFC +number+ has: { total: 5, verified: 3 }.
  def self.counts(number)
    errata = where(rfc: Integer(number))
    RfcModel.guard({ total: 0, verified: 0 }) { { total: errata.count, verified: errata.where(status: 'Verified').count } }
  end

  # Writes +rows+ (values in the order of ROW), an erratum of the same id
  # replaced.
  def self.insert_rows(rows) = dataset.insert_conflict(:replace).import(ROW, rows)

  def id = self[:id]

  def rfc = self[:rfc]

  def verified? = status == 'Verified'

  # Its page at the RFC Editor.
  def url = "rfc-editor.org/errata/eid#{id}"
end
