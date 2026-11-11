# frozen_string_literal: true

require 'test_helper'

class RatingServiceTest < Minitest::Test
  def setup = Rubbs::Test.database(MIGRATIONS)

  def ratings = @ratings ||= RatingService.new

  def stalker = Fixtures.catalog.find('Q2')

  def solaris = Fixtures.catalog.find('Q3')

  def test_stars_count_at_once_and_a_review_waits_for_an_admin
    assert_equal :ok, ratings.rate(stalker, identity: account, stars: '9', review: 'The Zone!', caller: 'a')
    assert_equal :ok, ratings.rate(stalker, identity: account(8, 'Bob'), stars: 6, caller: 'b')
    assert_equal [7.5, 2], ratings.score(stalker)
    assert_empty ratings.reviews(stalker)
    ratings.approve(ratings.pending.first.id)
    assert_equal ['The Zone!'], ratings.reviews(stalker).map(&:review)
    assert_equal '9/10, review shown', UI::Wording.yours(ratings.mine(account, stalker))
  end

  def test_rating_again_replaces_and_a_changed_review_waits_again
    ratings.rate(stalker, identity: account, stars: 9, review: 'Slow.', caller: 'a')
    ratings.approve(ratings.pending.first.id)
    ratings.rate(stalker, identity: account, stars: 8, review: 'Slow.', caller: 'a')
    assert_equal %w[8 approved], [ratings.mine(account, stalker).stars.to_s, ratings.mine(account, stalker).review_status]
    ratings.rate(stalker, identity: account, stars: 8, review: 'Slow, but worth it.', caller: 'a')
    assert_equal 'pending', ratings.mine(account, stalker).review_status
    assert_equal [8.0, 1], ratings.score(stalker)
  end

  def test_refusals
    assert_equal :account, ratings.rate(stalker, identity: guest, stars: 9, caller: 'a')
    assert_equal :stars, ratings.rate(stalker, identity: account, stars: '11', caller: 'a')
    assert_equal :stars, ratings.rate(stalker, identity: account, stars: 'x', caller: 'a')
    assert_equal :too_long, ratings.rate(stalker, identity: account, stars: 5, review: 'x' * 401, caller: 'a')
    RatingService::PER_CALLER.times { |n| ratings.rate(stalker, identity: account(n), stars: 5, caller: 'c') }
    assert_equal :rate_limited, ratings.rate(stalker, identity: account(99), stars: 5, caller: 'c')
  end

  def test_the_top_list_and_an_accounts_ratings
    ratings.rate(stalker, identity: account, stars: 9, caller: 'a')
    ratings.rate(solaris, identity: account, stars: 7, caller: 'a')
    ratings.rate(solaris, identity: account(8), stars: 9, caller: 'b')
    assert_equal([['Q2', 9.0, 1], ['Q3', 8.0, 2]], ratings.top.map { |id, _, _, avg, n| [id, avg, n] })
    assert_equal %w[Q3 Q2].sort, ratings.ratings_of(account).map(&:film_id).sort
    assert_equal :ok, ratings.unrate(stalker, account)
    assert_equal [nil, 0], ratings.score(stalker)
  end

  def test_the_lists_and_seeing_a_film_takes_it_off_the_watchlist
    assert_equal :added, ratings.toggle(account, stalker, 'watchlist')
    assert ratings.marked?(account, stalker, 'watchlist')
    assert_equal :added, ratings.toggle(account, stalker, 'seen')
    refute ratings.marked?(account, stalker, 'watchlist')
    assert_equal ['1979 Stalker'], ratings.list(account, 'seen').map(&:label)
    assert_equal :removed, ratings.toggle(account, stalker, 'seen')
    assert_equal :account, ratings.toggle(guest, stalker, 'seen')
    refute ratings.marked?(guest, stalker, 'seen')
  end
end
