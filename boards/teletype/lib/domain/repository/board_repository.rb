# frozen_string_literal: true

require_relative '../model/message_model'

# The message boards ("general", "tech"…), their posts in one table. A
# post's stamp is month, day and time, the way the boards always showed it.
class BoardRepository
  BoardMeta = Struct.new(:id, :title, :description)

  DEFAULT_BOARDS = [
    BoardMeta.new('general',  'General',  'Open chat, anything goes'),
    BoardMeta.new('tech',     'Tech',     'Hardware, software, code'),
    BoardMeta.new('offtopic', 'Off-Topic', 'Random topics, jokes'),
    BoardMeta.new('sysop',    'Sysop',     'Notes from the operator')
  ].freeze

  attr_reader :boards

  def initialize(db, boards: DEFAULT_BOARDS)
    @db     = db
    @boards = boards
  end

  def append(board_id, username, text)
    msg = MessageModel.new(Time.now.strftime('%m-%d %H:%M'), username, text)
    @db.insert('INSERT INTO posts (board, timestamp, username, user_key, text) VALUES (?, ?, ?, ?, ?)',
               board_id, msg.timestamp, username, Names.key(username), text)
    msg
  end

  # The newest +n+ posts of a board, oldest first.
  def last(board_id, n = 30)
    @db.query('SELECT * FROM posts WHERE board = ? ORDER BY id DESC LIMIT ?', board_id, n).reverse.map { |r| message(r) }
  end

  # The newest +n+ posts over every board, newest first: [[board id, message], ...].
  def latest(n)
    @db.query("SELECT * FROM posts WHERE board IN (#{marks}) ORDER BY id DESC LIMIT ?", *ids, n)
       .map { |row| [row['board'], message(row)] }
  end

  def count(board_id) = @db.get('SELECT COUNT(*) AS n FROM posts WHERE board = ?', board_id)['n']

  def total_count = @db.get("SELECT COUNT(*) AS n FROM posts WHERE board IN (#{marks})", *ids)['n']

  def posts_by(name) = @db.get('SELECT COUNT(*) AS n FROM posts WHERE user_key = ?', Names.key(name))['n']

  # [[name, posts], ...] most posts first, +except+ left out; a name is
  # shown the way it last posted.
  def top_posters(n, except:)
    @db.query(<<~SQL, Names.key(except), n).map { |row| [row['username'], row['posts']] }
      SELECT username, MAX(id), COUNT(*) AS posts FROM posts WHERE user_key != ?
      GROUP BY user_key ORDER BY posts DESC, user_key LIMIT ?
    SQL
  end

  private

  def ids = @boards.map(&:id)

  def marks = (['?'] * @boards.size).join(', ')

  def message(row) = MessageModel.new(row['timestamp'], row['username'], row['text'])
end
