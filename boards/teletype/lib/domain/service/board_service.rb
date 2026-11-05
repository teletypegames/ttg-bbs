# frozen_string_literal: true

# The message boards: reading them, what a registered name has not read
# yet, and posting, one post in COOLDOWN seconds a name and a line.
class BoardService
  COOLDOWN   = 30
  MAX_LENGTH = 1000

  BOARDS = [
    BoardModel.new('general',  'General',  'Open chat, anything goes'),
    BoardModel.new('tech',     'Tech',     'Hardware, software, code'),
    BoardModel.new('offtopic', 'Off-Topic', 'Random topics, jokes'),
    BoardModel.new('sysop',    'Sysop',     'Notes from the operator')
  ].freeze

  attr_reader :boards

  # +store+ is the Sequel::Database the cooldown is kept in; nil keeps it
  # in memory.
  def initialize(store: nil, boards: BOARDS)
    @boards   = boards
    @throttle = Throttle.new(limit: 1, per: COOLDOWN, store: store, name: 'post')
  end

  def board(id)            = boards.find { |b| b.id == id }
  def messages(id, n = 30) = PostModel.newest(id, n)
  def count(id)            = PostModel.count_on(id)
  def total_count          = PostModel.count_on(ids)
  def posts_by(name)       = PostModel.count_by(name)

  # Unread messages of a registered name on a board. A name that never
  # opened the board has read nothing of it.
  def unread(username, board_id)
    return 0 unless username

    [count(board_id) - (LastReadModel.count_of(username, board_id) || 0), 0].max
  end

  # {board => unread} for the boards with something new.
  def new_scan(username)
    boards.to_h { |b| [b, unread(username, b.id)] }.select { |_, n| n.positive? }
  end

  def mark_read(username, board_id)
    LastReadModel.mark(username, board_id, count(board_id)) if username
  end

  # The newest posts over every board, newest first: [[board, message], ...].
  def latest(n = 5) = PostModel.latest(ids, n).map { |post| [board(post.board), post] }

  # [[name, posts], ...] most posts first.
  def top_posters(n = 10) = PostModel.top_posters(n, except: MemberService::ANONYMOUS)

  # :ok, :empty, :unknown (no such board) or :too_fast.
  def post(board_id, username, text, caller_key:)
    body = Rubbs::Common::Text.clean(text).strip
    return :empty if body.empty?
    return :unknown unless board(board_id)
    return :too_fast unless @throttle.allow?(username, caller_key)

    PostModel.append(board_id, username, body[0, MAX_LENGTH])
    :ok
  end

  private

  def ids = boards.map(&:id)
end
