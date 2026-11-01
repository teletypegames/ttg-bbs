# frozen_string_literal: true

require 'time'

# Every finished call, the board's call history: the last callers, the
# caller numbers, a name's calls and the top callers. Rows imported from
# before the call length was logged have no seconds.
class LastCallersRepository
  Caller = Struct.new(:timestamp, :username, :session_id, :seconds) do
    def time = Time.parse(timestamp)
  end
  Stats = Struct.new(:calls, :first_call, :last_call, :seconds, keyword_init: true)

  # The calls of each name: how many, the first and the last one, the time
  # on line.
  STATS = <<~SQL
    SELECT g.user_key, g.calls, g.seconds, f.timestamp AS first, l.timestamp AS last
    FROM (SELECT user_key, COUNT(*) AS calls, COALESCE(SUM(seconds), 0) AS seconds,
                 MIN(id) AS first_id, MAX(id) AS last_id
          FROM calls %<where>s GROUP BY user_key) AS g
    JOIN calls AS f ON f.id = g.first_id JOIN calls AS l ON l.id = g.last_id
  SQL

  def initialize(db) = @db = db

  def record(username, session_id, seconds = nil)
    entry = Caller.new(Time.now.iso8601, username, session_id, seconds&.to_i)
    @db.insert('INSERT INTO calls (timestamp, username, user_key, session_id, seconds) VALUES (?, ?, ?, ?, ?)',
               entry.timestamp, username, Names.key(username), session_id, entry.seconds)
    entry
  end

  # The newest +n+ calls, newest first.
  def recent(n = 10)
    @db.query('SELECT * FROM calls ORDER BY id DESC LIMIT ?', n)
       .map { |row| Caller.new(row['timestamp'], row['username'], row['session_id'], row['seconds']) }
  end

  def count = @db.get('SELECT COUNT(*) AS n FROM calls')['n']

  # The calls whose stamp starts with +prefix+ ("2026-11-01" for a day).
  def count_since(prefix) = @db.get('SELECT COUNT(*) AS n FROM calls WHERE timestamp LIKE ?', "#{prefix}%")['n']

  # The Stats of +name+, nil before its first call.
  def stats(name)
    row = @db.get(format(STATS, where: 'WHERE user_key = ?'), Names.key(name))
    row && stats_of(row)
  end

  # {name key => Stats} of every name that called.
  def all_stats = @db.query(format(STATS, where: '')).to_h { |row| [row['user_key'], stats_of(row)] }

  # [[name, calls], ...] most calls first, +except+ left out; a name is
  # shown the way it last called.
  def top(n, except:)
    @db.query(<<~SQL, Names.key(except), n).map { |row| [row['username'], row['calls']] }
      SELECT username, MAX(id), COUNT(*) AS calls FROM calls WHERE user_key != ?
      GROUP BY user_key ORDER BY calls DESC, user_key LIMIT ?
    SQL
  end

  private

  def stats_of(row)
    Stats.new(calls: row['calls'], first_call: Time.parse(row['first']), last_call: Time.parse(row['last']),
              seconds: row['seconds'])
  end
end
