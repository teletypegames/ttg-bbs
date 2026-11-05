# frozen_string_literal: true

# The calls to the debrief terminal, one row a call, in a SQLite file
# (Rubbs::Common::Storage::Store, the impostor gem's sessions store). The board kept them in a
# CSV file before: when data/sessions.csv sits beside the database, Rubbs::Common::Storage::Store
# imports it once (setting its broken lines aside in sessions.csv.rejected)
# and renames it to sessions.csv.imported.
class SessionRepository
  def initialize(path)
    @store = Impostor.sessions_store(path.to_s.sub(/\.sqlite3\z/, '.csv'))
  end

  # Opens the database now, so a legacy CSV file is imported at boot.
  # Returns +self+.
  def open!
    @store.open!
    self
  end

  # Adds the row of +session_id+ or updates it with +fields+.
  def save(session_id, fields) = @store.upsert(session_id: session_id, **fields)

  # The SessionModel of +session_id+, or +nil+.
  def find(session_id) = @store.find(session_id)&.then { |row| SessionModel.from_row(row) }
end
