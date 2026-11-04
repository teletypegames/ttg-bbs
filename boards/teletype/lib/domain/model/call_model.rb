# frozen_string_literal: true

require 'time'

# A finished call, the board's call history: the last callers, the caller
# numbers, a name's calls and the top callers. Rows imported from before
# the call length was logged have no seconds.
class CallModel < BBS::Model
  table :calls

  # A name's calls: how many, the first and the last one, the time on line.
  Stats = Struct.new(:calls, :first_call, :last_call, :seconds, keyword_init: true)

  # The calls of each name, for Stats.
  STATS = <<~SQL
    SELECT g.user_key, g.calls, g.seconds, f.timestamp AS first, l.timestamp AS last
    FROM (SELECT user_key, COUNT(*) AS calls, COALESCE(SUM(seconds), 0) AS seconds,
                 MIN(id) AS first_id, MAX(id) AS last_id
          FROM calls %<where>s GROUP BY user_key) AS g
    JOIN calls AS f ON f.id = g.first_id JOIN calls AS l ON l.id = g.last_id
  SQL

  # A name's calls with the most first, +except+ left out; a name is shown
  # the way it last called.
  TOP = <<~SQL
    SELECT username, MAX(id), COUNT(*) AS calls FROM calls WHERE user_key != ?
    GROUP BY user_key ORDER BY calls DESC, user_key LIMIT ?
  SQL

  def self.record(username, session_id, seconds = nil)
    create(
      timestamp:  Time.now.iso8601,
      username:   username,
      user_key:   BBS::Auth::Names.key(username),
      session_id: session_id,
      seconds:    seconds&.to_i
    )
  end

  # The newest +n+ calls, newest first.
  def self.recent(n) = reverse(:id).limit(n).all

  # The calls whose stamp starts with +prefix+ ("2026-11-01" for a day).
  def self.count_since(prefix) = where(Sequel.like(:timestamp, "#{prefix}%")).count

  # The Stats of +name+, nil before its first call.
  def self.stats(name)
    row = db.fetch(format(STATS, where: 'WHERE user_key = ?'), BBS::Auth::Names.key(name)).first
    row && stats_of(row)
  end

  # {name key => Stats} of every name that called.
  def self.all_stats = db.fetch(format(STATS, where: '')).to_h { |row| [row[:user_key], stats_of(row)] }

  # [[name, calls], ...] most calls first, +except+ left out.
  def self.top(n, except:) = db.fetch(TOP, BBS::Auth::Names.key(except), n).map { |row| [row[:username], row[:calls]] }

  def self.stats_of(row)
    Stats.new(
      calls:      row[:calls],
      first_call: Time.parse(row[:first]),
      last_call:  Time.parse(row[:last]),
      seconds:    row[:seconds]
    )
  end
  private_class_method :stats_of

  def time = Time.parse(timestamp)
end
