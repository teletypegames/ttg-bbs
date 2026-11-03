# frozen_string_literal: true

# The errata of the RFCs, part of IndexRepository: what the RFC Editor's
# errata.json says is wrong in an RFC, and how it reads when corrected.
module IndexErrata
  ERRATA_COLUMNS = 'id, rfc, status, type, section, orig_text, correct_text, notes, submitted'

  # The errata of RFC +number+ (ErratumModel), the verified ones first, then
  # by id.
  def errata(number)
    query("SELECT #{ERRATA_COLUMNS} FROM errata WHERE rfc = ? ORDER BY status != 'Verified', id", [Integer(number)])
      .map { |r| ErratumModel.from_row(r) }
  end

  # How many errata RFC +number+ has: { total: 5, verified: 3 }.
  def errata_count(number)
    row = query("SELECT COUNT(*) AS total, SUM(status = 'Verified') AS verified FROM errata WHERE rfc = ?",
                [Integer(number)]).first || {}
    { total: row['total'].to_i, verified: row['verified'].to_i }
  end
end
