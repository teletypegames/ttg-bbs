# frozen_string_literal: true

# The shelves of the index, part of IndexRepository: the statuses, the
# decades, the newest, the RFCs of a month and the IENs. The IENs (negative
# numbers) are on their own shelf only.
module IndexShelves
  # How many RFCs there are of each status, the most first: [[status, n]].
  def statuses
    query('SELECT status, COUNT(*) AS n FROM rfcs WHERE issued = 1 AND number > 0 GROUP BY status ORDER BY n DESC')
      .map { |r| [r['status'], r['n']] }
  end

  # The RFCs of +status+, the newest first.
  def with_status(status, limit:)
    rows('WHERE issued = 1 AND number > 0 AND status = ? ORDER BY number DESC LIMIT ?', status, limit)
  end

  # How many RFCs each decade has: [[1960, 1], [1970, 700], …].
  def decades
    query('SELECT (year / 10) * 10 AS decade, COUNT(*) AS n FROM rfcs WHERE issued = 1 AND number > 0 ' \
          'GROUP BY decade ORDER BY decade').map { |r| [r['decade'], r['n']] }
  end

  # The RFCs of the ten years from +decade+, by number.
  def of_decade(decade, limit:)
    rows('WHERE issued = 1 AND number > 0 AND year BETWEEN ? AND ? ORDER BY number LIMIT ?', decade, decade + 9, limit)
  end

  # The +n+ RFCs of the highest numbers.
  def newest(n) = rows('WHERE issued = 1 AND number > 0 ORDER BY number DESC LIMIT ?', n)

  # The RFCs published in +month+ (1-12) of any year, the oldest first.
  def of_month(month, limit:)
    rows('WHERE issued = 1 AND number > 0 AND substr(date, 6, 2) = ? ORDER BY date, number LIMIT ?',
         format('%02d', month), limit)
  end

  # How many RFCs were published in +month+ of any year.
  def month_count(month)
    query('SELECT COUNT(*) AS n FROM rfcs WHERE issued = 1 AND number > 0 AND substr(date, 6, 2) = ?',
          [format('%02d', month)]).first&.fetch('n') || 0
  end

  # The IENs, by number.
  def iens = rows('WHERE number < 0 ORDER BY number DESC')

  private

  def rows(where, *params)
    query("SELECT #{IndexRepository::COLUMNS} FROM rfcs #{where}", params).map { |r| RfcModel.from_row(r) }
  end
end
