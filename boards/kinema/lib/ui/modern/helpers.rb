# frozen_string_literal: true

module UI
  module Modern
    # What the caller does on the modern face: the searches, the lists, a
    # film's page and its buttons, a person's films, the articles, the
    # ratings and lists, the network's feedback and wall.
    module Helpers
      SHOWN = 30

      def search_films
        ask('A film title (English or Hungarian):', title: 'Search films', width: 60) do |text|
          found = loading('Asking Wikidata…') { films.search_films(text) }
          list_or_note(found, text, 'film', "Films: #{text.strip}") { Rows.hits(found) }
        end
      end

      def search_people
        ask('A name: an actor, a director, a writer…', title: 'Search people', width: 60) do |text|
          found = loading('Asking Wikidata…') { films.search_people(text) }
          list_or_note(found, text, 'person', "People: #{text.strip}") { Rows.hits(found, person: true) }
        end
      end

      def list_or_note(found, query, what, caption)
        return note(Wording.search(found, query, what), 'Search') unless found&.any?

        show(:rows, caption: caption, entries: yield)
      end

      def film_of_the_day
        film = catalog.film_of_the_day
        film ? open_film(film.id) : note('The shelf is empty.', 'Film of the day')
      end

      def on_this_day
        list = catalog.on_this_day(Date.today)
        return note('No film of the shelf was first released on this day.', 'On this day') if list.empty?

        show(:rows, caption: "First released on #{Date.today.strftime('%B %-d')}", entries: Rows.films(list))
      end

      def decade_groups = catalog.decades

      def group_name(kind, name) = kind == :decade ? "#{name}s" : name.to_s

      def films_of(kind, name) = kind == :decade ? catalog.of_decade(name) : catalog.of_genre(name)

      def open_group(kind, name) = show(:rows, caption: group_name(kind, name), entries: Rows.films(films_of(kind, name)))

      def group_card(kind, name, count, width)
        list = films_of(kind, name)
        [bright(group_name(kind, name)), accent("#{count} films on the shelf, the best known first"), '',
         *list.first(SHOWN).map { |f| Rubbs::Modern::FrameBuffer.clip_ansi(f.label, width - 1) },
         *(list.size > SHOWN ? [dim("… and #{list.size - SHOWN} more")] : [])]
      end

      def top_rated
        show(:rows, caption: 'Top rated by the callers', entries: Rows.top(ratings.top))
      end

      def recent_reviews
        show(:reviews, caption: 'Recent reviews', entries: ratings.recent_reviews, every: true)
      end

      def my_list(kind)
        return note(Wording::RATE[:account], Wording::LIST_NAMES[kind].capitalize) unless signed_in?

        show(:rows, caption: "My #{Wording::LIST_NAMES[kind]}", entries: Rows.marks(ratings.list(identity, kind)))
      end

      def my_ratings
        return note(Wording::RATE[:account], 'My ratings') unless signed_in?

        show(:rows, caption: 'My ratings', entries: Rows.ratings(ratings.ratings_of(identity)))
      end

      def open_row(row) = row.person? ? open_person(row.id) : open_film(row.id)

      def open_film(id)
        return unless id

        found = loading('Asking Wikidata…', failed: "Wikidata has no film #{id}, or did not answer.") { films.film(id) }
        show(:film, film: found) if found
      end

      def open_person(id)
        found = loading('Asking Wikidata…', failed: "Wikidata has no person #{id}, or did not answer.") { films.person(id) }
        show(:person, person: found) if found
      end

      def film_people(film)
        rows = Rows.people(film)
        return note('Wikidata names nobody who made it.', 'People') if rows.empty?

        show(:rows, caption: "People: #{film.title}", entries: rows)
      end

      def read_article(film, language = nil)
        return note('It has no Wikipedia article.', 'Wiki') unless film.wikipedia?

        found = loading('Asking Wikipedia…', failed: 'Wikipedia did not answer. Try again later.') do
          films.article(film, language)
        end
        show(:article, article: found, film: film) if found
      end

      # The film's article in the other language: Hungarian for English and
      # the other way round.
      def other_language(film, article)
        language = article.language == 'en' ? 'hu' : 'en'
        title    = language == 'hu' ? film.huwiki : film.enwiki
        return note("It has no #{language == 'hu' ? 'Hungarian' : 'English'} Wikipedia article.", 'Wiki') unless title

        read_article(film, language)
      end

      def rate(film)
        return note(Wording::RATE[:account], 'Rate') unless signed_in?

        show(:rate, film: film)
      end

      def mine = ratings.mine(identity, film)

      def lists(film)
        return note(Wording::RATE[:account], 'Lists') unless signed_in?

        show(:lists, film: film)
      end

      # Puts the film on the lists ticked in +values+ and off the others.
      def save_lists(film, values)
        ticked = { 'seen' => values[:seen], 'watchlist' => values[:watchlist] && !values[:seen] }
        ticked.each { |kind, on| ratings.toggle(identity, film, kind) if on != ratings.marked?(identity, film, kind) }
        :ok
      end

      def film_reviews(film)
        show(:reviews, caption: "Reviews: #{film.title}", entries: ratings.reviews(film), every: false)
      end

      # The lines of a film's page.
      def film_lines(film, width)
        facts = Wording.facts(film) + standing(film)
        [bright(film.title), *(film.description.empty? ? [] : [dim(film.description)]), '',
         *card(facts, width), '', *people_lines(film, width), '', dim(film.wikipedia_url || film.wikidata_url)]
      end

      # The callers' score, the caller's own rating and lists, as fact rows.
      def standing(film)
        rows  = [['Callers', Wording.score(*ratings.score(film))]]
        yours = Wording.yours(ratings.mine(identity, film))
        rows << ['Yours', yours] if yours
        lists = Wording::LIST_NAMES.filter_map { |kind, name| name if ratings.marked?(identity, film, kind) }
        rows << ['On your', lists.join(', ')] if lists.any?
        rows
      end

      def people_lines(film, width)
        return [] if film.cast.empty?

        [accent('Cast'), *wrap(film.cast.map(&:name).join(', '), width - 1), dim('People lists everyone, Enter opens them.')]
      end

      def person_card(person, width) = card(Wording.person_facts(person), width)

      def review_card(rating, width)
        [bright(rating.label), accent("#{Wording.stars(rating.stars)} #{rating.stars}/10"),
         dim("#{rating.handle} · #{rating.date}"), '',
         *wrap(rating.review, width - 1)]
      end

      # Something for the sysops (ttg-common TTG::Feedback), about the film
      # open, if any.
      def feedback = with_line { TTG::Feedback.open(@session, context: window(:film) && "Film: #{window(:film).title}") }

      # The board's wall (ttg-common TTG::Wall).
      def wall = with_line { TTG::Wall.open(@session) }

      def note(text, title) = message(text, title: title, width: 64)

      def wrap(text, width) = Rubbs::Modern::FrameBuffer.wrap_ansi(text.to_s, [width, 10].max)

      # [label, value] rows as lines, the labels dim in a column of their own.
      def card(rows, width)
        pad = rows.map { |k, _| k.size }.max.to_i + 2
        rows.flat_map do |key, value|
          lines = wrap(value.to_s, width - pad - 1)
          lines.each_with_index.map { |l, i| "#{dim((i.zero? ? key : '').ljust(pad))}#{l}" }
        end
      end
    end
  end
end
