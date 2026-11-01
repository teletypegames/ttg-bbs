# frozen_string_literal: true

# The message boards: reading them, what a registered name has not read
# yet, and posting, one post in COOLDOWN seconds a name and a line.
class BoardService
  COOLDOWN   = 30
  MAX_LENGTH = 1000

  def initialize(repo, last_read:)
    @repo      = repo
    @last_read = last_read
    @throttle  = Throttle.new(limit: 1, per: COOLDOWN)
  end

  def boards               = @repo.boards
  def board(id)            = boards.find { |b| b.id == id }
  def messages(id, n = 30) = @repo.last(id, n)
  def count(id)            = @repo.count(id)
  def total_count          = @repo.total_count
  def posts_by(name)       = @repo.posts_by(name)

  # Unread messages of a registered name on a board. A name that never
  # opened the board has read nothing of it.
  def unread(username, board_id)
    return 0 unless username

    [count(board_id) - (@last_read.get(username, board_id) || 0), 0].max
  end

  # {board => unread} for the boards with something new.
  def new_scan(username)
    boards.to_h { |b| [b, unread(username, b.id)] }.select { |_, n| n.positive? }
  end

  def mark_read(username, board_id)
    @last_read.set(username, board_id, count(board_id)) if username
  end

  # The newest posts over every board, newest first: [[board, message], ...].
  def latest(n = 5) = @repo.latest(n).map { |id, message| [board(id), message] }

  # [[name, posts], ...] most posts first.
  def top_posters(n = 10) = @repo.top_posters(n, except: AccountService::ANONYMOUS)

  # :ok, :empty, :unknown (no such board) or :too_fast.
  def post(board_id, username, text, caller_key:)
    body = BBS::Text.clean(text).strip
    return :empty if body.empty?
    return :unknown unless board(board_id)
    return :too_fast unless @throttle.allow?(username, caller_key)

    @repo.append(board_id, username, body[0, MAX_LENGTH])
    :ok
  end
end
