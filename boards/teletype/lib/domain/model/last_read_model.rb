# frozen_string_literal: true

# How far a registered name has read a board: the board's message count
# when the name last opened it. The new-message scan at logon compares it
# with the count now.
class LastReadModel < Rubbs::Common::Storage::Model
  table :last_read

  # The count +username+ last read of +board_id+, nil before the first time.
  def self.count_of(username, board_id) = where(user_key: Rubbs::Common::Auth::Names.key(username), board: board_id).get(:count)

  def self.mark(username, board_id, count)
    dataset.insert_conflict(target: %i[user_key board], update: { count: Sequel[:excluded][:count] })
      .insert(user_key: Rubbs::Common::Auth::Names.key(username), board: board_id, count: count)
  end
end
