# frozen_string_literal: true

# What the post office shows a caller at a glance: their MailboxSummaryModel, the newest letters to
# them (Hashes with +from+, +subject+, +new+) and the newest notes of the wall (+name+, +text+).
DeskModel = Data.define(:summary, :letters, :notes) do
  # The desk when the Central does not answer.
  def self.away = new(summary: MailboxSummaryModel.away, letters: [], notes: [])
end
