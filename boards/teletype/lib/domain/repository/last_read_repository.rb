# frozen_string_literal: true

# How far a registered name has read each board: the board's message count
# when the name last opened it. The new-message scan at logon compares it
# with the count now.
class LastReadRepository
  def initialize(db) = @db = db

  def get(username, board_id)
    @db.get('SELECT count FROM last_read WHERE user_key = ? AND board = ?', Names.key(username), board_id)&.fetch('count')
  end

  def set(username, board_id, count)
    @db.query('INSERT INTO last_read (user_key, board, count) VALUES (?, ?, ?) ' \
              'ON CONFLICT (user_key, board) DO UPDATE SET count = excluded.count',
              Names.key(username), board_id, count)
  end
end
