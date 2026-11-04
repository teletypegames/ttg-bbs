# frozen_string_literal: true

require 'time'

# A finished game of TTG Trivia, for its hall of fame.
class TriviaScoreModel < BBS::Model
  table :trivia_scores

  def self.add(username, points, correct)
    create(
      timestamp: Time.now.iso8601,
      username:  username,
      user_key:  Names.key(username),
      points:    points,
      correct:   correct
    )
  end

  # The +n+ best games, the earlier first of equal points.
  def self.best(n) = order(Sequel.desc(:points), :timestamp).limit(n).all
end
