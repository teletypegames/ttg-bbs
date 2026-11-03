# frozen_string_literal: true

# One erratum of an RFC from the RFC Editor's errata.json: its id, the RFC,
# its status ("Verified", "Reported", "Held for Document Update",
# "Rejected"), its type ("Technical", "Editorial"), the section, the text as
# published and as it should read, the notes, and the day it was reported.
ErratumModel = Data.define(:id, :rfc, :status, :type, :section, :orig_text, :correct_text, :notes, :submitted) do
  # The erratum of a row of the errata table.
  def self.from_row(row)
    new(id: row['id'], rfc: row['rfc'], **%i[status type section orig_text correct_text notes submitted]
      .to_h { |k| [k, row[k.to_s].to_s] })
  end

  def verified? = status == 'Verified'

  # Its page at the RFC Editor.
  def url = "rfc-editor.org/errata/eid#{id}"
end
