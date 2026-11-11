# frozen_string_literal: true

require 'time'

# An account's rating of a film: 1 to 10 stars and maybe a short review. A
# review waits as pending until an admin approves it with bin/reviews; the
# stars count at once. One rating an account and film: rating again
# replaces it.
class RatingModel < Rubbs::Common::Storage::Model
  table :ratings

  def self.of(account_id, film_id) = where(account_id: account_id.to_s, film_id: film_id).first

  def self.for_film(film_id) = where(film_id: film_id)

  # [average, count] of +film_id+'s stars; [nil, 0] for none.
  def self.score(film_id)
    row = for_film(film_id).select { [avg(:stars).as(:average), count.function.*.as(:count)] }.first
    [row[:average]&.to_f, row[:count].to_i]
  end

  # The approved reviews of +film_id+, the newest first.
  def self.reviews(film_id) = for_film(film_id).where(review_status: 'approved').reverse(:updated_at).all

  def self.by_account(account_id) = where(account_id: account_id.to_s).reverse(:updated_at).all

  # The newest approved reviews of every film.
  def self.recent_reviews(limit) = where(review_status: 'approved').reverse(:updated_at).limit(limit).all

  # [film_id, title, year, average, count] of the films with at least
  # +min+ ratings, the best first.
  def self.top(limit, min:)
    scores.having { count.function.* >= min }.order(Sequel.desc(:average), Sequel.desc(:count), :title).limit(limit).all
      .map { |r| [r[:film_id], r[:title], r[:year], r[:average].to_f, r[:count].to_i] }
  end

  # Every rated film's id, title, year, average and count.
  def self.scores
    dataset.select { [film_id, max(title).as(:title), max(year).as(:year), avg(stars).as(:average), count.function.*.as(:count)] }
      .group(:film_id)
  end

  def self.with_review_status(status, limit: 100) = where(review_status: status).reverse(:updated_at).limit(limit).all

  def label = [year, title].compact.join(' ')

  def date = updated_at.to_s[0, 10]

  def review? = !review.to_s.empty?
end
