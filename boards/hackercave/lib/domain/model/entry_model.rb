# frozen_string_literal: true

# An RFC on a list, with what the list says about it. +kind+ says what the
# +note+ is: :remark (a line of a curated shelf), :series (the series it
# stands for, "STD 7"), :relation (how it is related to the RFC a list of
# links is of, "obsoleted by") or :reads (how many times it was read here,
# an Integer); nil with no note.
EntryModel = Data.define(:rfc, :note, :kind) do
  def self.of(rfc, note = nil, kind = nil) = new(rfc: rfc, note: note, kind: note.nil? ? nil : kind)

  def number = rfc.number
end
