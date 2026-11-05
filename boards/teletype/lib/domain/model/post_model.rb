# frozen_string_literal: true

# A post on a message board. Its stamp is month, day and time, the way the
# boards always showed it.
class PostModel < Rubbs::Common::Storage::Model
  table :posts

  STAMP = '%m-%d %H:%M'

  # A name's posts with the most first, +except+ left out; a name is shown
  # the way it last posted.
  TOP = <<~SQL
    SELECT username, MAX(id), COUNT(*) AS posts FROM posts WHERE user_key != ?
    GROUP BY user_key ORDER BY posts DESC, user_key LIMIT ?
  SQL

  def self.append(board_id, username, text)
    create(
      board:     board_id,
      timestamp: Time.now.strftime(STAMP),
      username:  username,
      user_key:  Rubbs::Common::Auth::Names.key(username),
      text:      text
    )
  end

  # The newest +n+ posts of a board, oldest first.
  def self.newest(board_id, n) = where(board: board_id).reverse(:id).limit(n).all.reverse

  # The newest +n+ posts on the boards +board_ids+, newest first.
  def self.latest(board_ids, n) = where(board: board_ids).reverse(:id).limit(n).all

  # The posts on the boards +board_ids+ (one id or several).
  def self.count_on(board_ids) = where(board: board_ids).count

  def self.count_by(name) = where(user_key: Rubbs::Common::Auth::Names.key(name)).count

  # [[name, posts], ...] most posts first, +except+ left out.
  def self.top_posters(n, except:)
    db.fetch(TOP, Rubbs::Common::Auth::Names.key(except), n).map { |row| [row[:username], row[:posts]] }
  end
end
