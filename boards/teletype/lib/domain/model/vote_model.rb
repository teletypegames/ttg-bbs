# frozen_string_literal: true

require 'time'

# A ballot of the Voting Booth: one per poll and name, kept by the chosen
# option's text. A name that votes again changes its ballot.
class VoteModel < BBS::Model
  table :votes

  def self.cast(poll_id, username, option)
    dataset.insert_conflict(:replace)
           .insert(poll: poll_id, user_key: Names.key(username), option: option, timestamp: Time.now.iso8601)
  end

  # The option +username+ chose in the poll, or nil.
  def self.ballot(poll_id, username) = where(poll: poll_id, user_key: Names.key(username)).get(:option)

  # {option => votes}
  def self.tally(poll_id) = where(poll: poll_id).group_and_count(:option).to_h { |row| [row[:option], row[:count]] }
end
