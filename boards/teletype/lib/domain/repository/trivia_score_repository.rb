# frozen_string_literal: true

require 'time'

# TTG Trivia's hall of fame: every finished game of a name.
class TriviaScoreRepository
  Score = Struct.new(:timestamp, :username, :points, :correct)

  def initialize(db) = @db = db

  def add(username, points, correct)
    @db.insert('INSERT INTO trivia_scores (timestamp, username, user_key, points, correct) VALUES (?, ?, ?, ?, ?)',
               Time.now.iso8601, username, Names.key(username), points, correct)
  end

  # The +n+ best games, the earlier first of equal points.
  def best(n)
    @db.query('SELECT * FROM trivia_scores ORDER BY points DESC, timestamp LIMIT ?', n)
       .map { |row| Score.new(row['timestamp'], row['username'], row['points'], row['correct']) }
  end
end
