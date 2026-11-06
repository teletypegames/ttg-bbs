# frozen_string_literal: true

require 'time'

# A letter of the board's mail of before the network's feedback (ttg-common
# TTG::Feedback), kept as the archive: between registered names, or a
# caller's feedback to the sysop (addressed to SYSOP), with when it was
# handed over to the feedback (+exported_at+). The letters between names
# are never handed over.
class LetterModel < Rubbs::Common::Storage::Model
  table :mail
  unrestrict_primary_key

  # The box the sysops read.
  SYSOP = 'Sysop'

  # The letters to the sysop not handed over yet, oldest first.
  def self.unexported_to_sysop
    where(recipient_key: Rubbs::Common::Auth::Names.key(SYSOP), exported_at: nil).order(Sequel.lit('rowid')).all
  end

  # The letter as a row of TTG::Feedback's import, read already.
  def to_feedback
    {
      kind:       'feedback',
      name:       sender,
      subject:    subject,
      body:       body,
      created_at: ExportService.utc(timestamp),
      state:      'read'
    }
  end
end
