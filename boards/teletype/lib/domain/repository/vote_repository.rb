# frozen_string_literal: true

require 'time'

# The ballots of the Voting Booth: one per poll and name, kept by the
# chosen option's text. A name that votes again changes its ballot.
class VoteRepository
  def initialize(db) = @db = db

  def cast(poll_id, username, option)
    @db.query('INSERT OR REPLACE INTO votes (poll, user_key, option, timestamp) VALUES (?, ?, ?, ?)',
              poll_id, Names.key(username), option, Time.now.iso8601)
  end

  def ballot(poll_id, username)
    @db.get('SELECT option FROM votes WHERE poll = ? AND user_key = ?', poll_id, Names.key(username))&.fetch('option')
  end

  # {option => votes}
  def tally(poll_id)
    @db.query('SELECT option, COUNT(*) AS n FROM votes WHERE poll = ? GROUP BY option', poll_id)
       .to_h { |row| [row['option'], row['n']] }
  end
end
