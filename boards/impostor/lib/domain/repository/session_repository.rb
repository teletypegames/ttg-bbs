# frozen_string_literal: true

require 'csv'

# The calls to the debrief terminal, one row a call, in a SQLite file
# (BBS::Store, the impostor gem's sessions store). The board kept them in a
# CSV file before: when data/sessions.csv sits beside the database, BBS::Store
# imports it once and renames it to sessions.csv.imported.
class SessionRepository
  def initialize(path)
    csv = path.to_s.sub(/\.sqlite3\z/, '.csv')
    reject_malformed_lines(csv)
    @store = Impostor.sessions_store(csv)
  end

  # The number of calls kept. The first read opens the database, and so
  # imports a legacy CSV file.
  def count = @store.all.size

  # Adds the row of +session_id+ or updates it with +fields+.
  def save(session_id, fields) = @store.upsert(session_id: session_id, **fields)

  # The SessionModel of +session_id+, or +nil+.
  def find(session_id) = @store.find(session_id)&.then { |row| SessionModel.from_row(row) }

  private

  # BBS::Store imports a CSV file whole and fails on a malformed one, so its
  # lines that do not parse go to <csv>.rejected first; the good ones stay.
  def reject_malformed_lines(csv)
    return unless File.exist?(csv)
    good, bad = File.binread(csv).lines.partition { |line| parses?(line) }
    return if bad.empty?
    File.binwrite("#{csv}.rejected", bad.join)
    File.binwrite("#{csv}.tmp", good.join)
    File.rename("#{csv}.tmp", csv)
    warn "impostor-bbs: #{bad.size} malformed lines of #{csv} set aside in #{csv}.rejected"
  end

  def parses?(line)
    CSV.parse_line(BBS::Text.utf8(line))
    true
  rescue CSV::MalformedCSVError
    false
  end
end
