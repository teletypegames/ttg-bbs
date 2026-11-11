# frozen_string_literal: true

module UI
  # What both faces tell the caller: a film's and a person's facts, the
  # scores, and the words for the answers of the services.
  module Wording
    TAGLINE = 'the film catalog on a telnet line'

    ABOUT = 'Kinema BBS — the film catalog of Teletype Games: search any film or anyone who made one, read ' \
            'their pages and the Wikipedia articles, keep a watchlist and a list of the films you have seen, ' \
            'and rate them with the other callers.'

    SOURCES = 'The films and people come from Wikidata (wikidata.org), under CC0, asked live; the best known ' \
              'films (those with an article on at least 30 wikis) are kept on the board too, refreshed every ' \
              'week, for the film of the day, the release days and the decades. Wikidata is edited by anyone, ' \
              'so a fact may be missing or wrong: fix it there and it shows here. The articles are Wikipedia\'s ' \
              '(English or Hungarian), under CC BY-SA 4.0, with their addresses. The stars and reviews are the ' \
              'callers\'; an admin reads a review before it shows. No IMDb data is used; the IMDb id is ' \
              'Wikidata\'s.'

    NO_ANSWER = 'Wikidata did not answer. Try again later.'

    # What becomes of a rating (RatingService#rate).
    RATE = {
      ok:           'Rated. A review waits for an admin and shows once approved.',
      account:      'A rating goes under your name: log in or make an account first (your profile).',
      stars:        "Give it #{RatingService::STARS.min} to #{RatingService::STARS.max} stars.",
      too_long:     "A review is at most #{RatingService::MAX_REVIEW} characters.",
      rate_limited: "That is enough ratings for now: #{RatingService::PER_CALLER} an hour.",
      failed:       'The rating could not be saved. Try again later.'
    }.freeze

    LIST_NAMES = { 'watchlist' => 'watchlist', 'seen' => 'films seen' }.freeze

    module_function

    # The facts of +film+ as [label, text] pairs, the empty ones left out.
    def facts(film)
      [['Hungarian title', film.other_title], ['Year', film.year&.to_s], ['Length', film.minutes && "#{film.minutes} min"],
       ['Directed by', film.directors], ['Written by', film.writers], ['Music', film.composers],
       ['Camera', film.cinematographers], ['Produced by', film.producers], ['Genre', genres(film.genres)],
       ['Country', film.countries], ['Language', film.languages], ['Based on', film.based_on],
       ['Follows', film.follows], ['Followed by', film.followed_by], ['Company', film.companies],
       ['IMDb', film.imdb]].filter_map do |label, value|
        text = Array(value).join(', ')
        [label, text] unless text.empty?
      end
    end

    def genres(list) = list.map { |g| CatalogFilmModel.genre(g.to_s) }

    # The facts of +person+ as [label, text] pairs.
    def person_facts(person)
      [['About', person.description], ['Born', [person.born, person.birthplace].compact.join(', ')],
       ['Died', person.died&.to_s], ['Films', person.credits.size.to_s]].reject { |_, v| v.to_s.empty? }
    end

    # "7.5/10 from 4 callers", "not rated yet".
    def score(average, count)
      return 'not rated yet' if count.zero?

      "#{format('%.1f', average).sub(/\.0\z/, '')}/10 from #{count} caller#{'s' unless count == 1}"
    end

    # "your 8/10, review waiting" and the like, or nil.
    def yours(rating)
      return nil unless rating

      note = { 'pending' => ', review waiting', 'approved' => ', review shown', 'rejected' => ', review not shown' }
      "#{rating.stars}/10#{note[rating.review_status]}"
    end

    def search(result, query, what)
      return NO_ANSWER if result.nil?

      "No #{what} found for \"#{query}\"." if result.empty?
    end

    def stars(count) = "#{'*' * count}#{'.' * (10 - count)}"
  end
end
