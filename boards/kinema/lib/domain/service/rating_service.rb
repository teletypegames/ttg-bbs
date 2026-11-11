# frozen_string_literal: true

# The callers' ratings and lists. An account rates a film 1 to 10 stars,
# with a short review if it likes; the stars count at once, a review waits
# as pending until an admin approves it (bin/reviews). An account keeps a
# watchlist and a list of the films it has seen. A caller (by address:
# Rubbs::Common::Line::RateLimit.caller_key) may rate PER_CALLER times an
# hour, and the whole board takes at most BOARD_MAX ratings an hour.
class RatingService
  STARS      = (1..10)
  MAX_REVIEW = 400
  PER_CALLER = 30
  BOARD_MAX  = 300
  WINDOW     = 3600
  # A film needs this many ratings for the top list.
  TOP_MIN    = 1
  TOP_SIZE   = 50

  def initialize
    @per_caller = Rubbs::Common::Line::RateLimit.new(limit: PER_CALLER, per: WINDOW)
    @board      = Rubbs::Common::Line::RateLimit.new(limit: BOARD_MAX, per: WINDOW)
  end

  # [average, count] of +film+'s stars.
  def score(film) = RatingModel.score(film.id)

  # The RatingModel of +identity+ for +film+, or nil.
  def mine(identity, film) = identity.signed_in? ? RatingModel.of(identity.id, film.id) : nil

  def reviews(film) = RatingModel.reviews(film.id)

  def recent_reviews(limit = 40) = RatingModel.recent_reviews(limit)

  # The best rated films: [film_id, title, year, average, count].
  def top = RatingModel.top(TOP_SIZE, min: TOP_MIN)

  def ratings_of(identity) = identity.signed_in? ? RatingModel.by_account(identity.id) : []

  # Rates +film+ for the account +identity+ from +caller+: :ok, or why not:
  # :account, :stars, :too_long, :rate_limited, :failed. A new or changed
  # review waits for an admin; an unchanged one keeps its state.
  def rate(film, identity:, stars:, caller:, review: '')
    return :account unless identity.signed_in?

    stars  = Integer(stars.to_s.strip, exception: false)
    review = clean(review)
    return :stars unless stars && STARS.cover?(stars)
    return :too_long if review.size > MAX_REVIEW
    return :rate_limited unless Rubbs::Common::Line::RateLimit.allow_all?([[@per_caller, caller], [@board, :board]])

    saved = save(film, identity, stars, review)
    Rubbs.achieve(:rating, ref: film.id, title: film.title) if saved == :ok
    saved
  end

  # Takes back +identity+'s rating of +film+: :ok or :none.
  def unrate(film, identity)
    return :none unless identity.signed_in?

    RatingModel.where(account_id: identity.id.to_s, film_id: film.id).delete.positive? ? :ok : :none
  end

  # Whether +film+ is on +identity+'s +kind+ list ('watchlist', 'seen').
  def marked?(identity, film, kind) = identity.signed_in? && MarkModel.marked?(identity.id, film.id, kind)

  # Puts +film+ on +identity+'s +kind+ list or takes it off: :added,
  # :removed, or :account. Seeing a film takes it off the watchlist.
  def toggle(identity, film, kind)
    return :account unless identity.signed_in?
    raise ArgumentError, "no list #{kind}" unless MarkModel::KINDS.include?(kind)

    return :removed if marks(identity, film, kind).delete.positive?

    MarkModel.dataset.insert_ignore.insert(
      account_id: identity.id.to_s,
      film_id:    film.id,
      kind:       kind,
      title:      film.title,
      year:       film.year,
      created_at: now
    )
    seen(identity, film) if kind == 'seen'
    :added
  end

  # The MarkModels of +identity+'s +kind+ list, the newest first.
  def list(identity, kind) = identity.signed_in? ? MarkModel.of(identity.id, kind) : []

  def pending(limit = 100) = RatingModel.with_review_status('pending', limit: limit)

  def approved_list(limit = 100) = RatingModel.with_review_status('approved', limit: limit)

  # :ok or :no_review.
  def approve(id) = review_status(id, 'approved')

  def reject(id) = review_status(id, 'rejected')

  private

  def marks(identity, film, kind) = MarkModel.where(account_id: identity.id.to_s, film_id: film.id, kind: kind)

  # A film seen is off the watchlist, and the :seen event.
  def seen(identity, film)
    marks(identity, film, 'watchlist').delete
    Rubbs.achieve(:seen, ref: film.id, title: film.title)
  end

  # The state of a +review+ saved over the +old+ rating: none for no
  # review, the old state for the same review, else pending.
  def status_of(review, old)
    return 'none' if review.empty?

    old && old.review == review ? old.review_status : 'pending'
  end

  def save(film, identity, stars, review)
    old    = RatingModel.of(identity.id, film.id)
    status = status_of(review, old)
    values = {
      handle:        clean(identity.name)[0, 20],
      title:         film.title,
      year:          film.year,
      stars:         stars,
      review:        review,
      review_status: status,
      updated_at:    now
    }
    if old
      RatingModel.where(id: old.id).update(values)
    else
      RatingModel.dataset.insert(values.merge(account_id: identity.id.to_s, film_id: film.id, created_at: now))
    end
    :ok
  rescue StandardError => e
    Rubbs.log('ratings', "saving a rating: #{e.class}: #{e.message}")
    :failed
  end

  def review_status(id, value)
    RatingModel.where(id: id.to_i).exclude(review_status: 'none').update(review_status: value).positive? ? :ok : :no_review
  end

  def now = Time.now.utc.iso8601

  # One line of text: no control or bidirectional character, one space
  # between words.
  def clean(text) = Rubbs::Common::Text.clean(text.to_s).gsub(/[[:space:]]+/, ' ').strip
end
