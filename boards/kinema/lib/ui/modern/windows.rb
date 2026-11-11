# frozen_string_literal: true

module UI
  module Modern
    # The windows of the modern face.
    module Windows
      # A list of films or people (UI::Row): the labels on the left, the
      # picked one's note on the right; Enter opens it.
      module RowsWindow
        extend Rubbs::Modern::Part

        window :rows, :master_detail do
          empty 'Nothing here.'
          height(-6)
          title      { caption }
          list_width { [40, cols * 2 / 5].max }
          items      { entries }
          label      :label
          detail     { |row, width| [bright(row.label), '', *wrap(row.note, width - 1), '', dim(row.id)] }
          meta       { |row| row.person? ? 'Enter opens their films' : 'Enter opens the film' }
          on_pick    { |row| open_row(row) }
          action('&Open') { |row| open_row(row) }
        end
      end

      # The decades or the genres, each with its count; the right pane lists
      # the best known films of the one picked.
      module GroupsWindow
        extend Rubbs::Modern::Part

        window :groups, :master_detail do
          empty 'Nothing here.'
          height(-6)
          title      { caption }
          list_width { [28, cols / 4].max }
          items      { groups }
          label      { |(name, count)| "#{group_name(kind, name)} (#{count})" }
          detail     { |(name, count), width| group_card(kind, name, count, width) }
          meta       { 'Enter lists the films' }
          on_pick    { |(name, _count)| open_group(kind, name) }
        end
      end

      # A film's page: its facts, the callers' score and the caller's own
      # rating and lists; the buttons read its articles, list its people,
      # rate it, put it on a list, show the reviews and its QR code.
      module FilmWindow
        extend Rubbs::Modern::Part

        window :film, :reader do
          title     { film.label }
          max_width 90
          lines     { |width| film_lines(film, width) }
          where     { film.wikidata_url }
          action('&Wiki')    { read_article(film) }
          action('&People')  { film_people(film) }
          action('Ra&te…')   { rate(film) }
          action('&Lists…')  { lists(film) }
          action('Re&views') { film_reviews(film) }
        end
      end

      # A person's films, the newest first, their parts on the right.
      module PersonWindow
        extend Rubbs::Modern::Part

        window :person, :master_detail do
          empty 'Wikidata lists no films of theirs.'
          height(-6)
          title      { person.heading }
          list_width { [40, cols * 2 / 5].max }
          items      { Rows.credits(person) }
          label      :label
          detail     { |row, width| [bright(row.label), '', *wrap(row.note, width - 1), '', *person_card(person, width)] }
          meta       { person.description }
          on_pick    { |row| open_film(row.id) }
          action('&Open') { |row| open_film(row.id) }
          action('&QR code') { qr("https://www.wikidata.org/wiki/#{person.id}", title: person.name) }
        end
      end

      # A Wikipedia article: its sections on the left, the picked one as
      # Markdown on the right.
      module ArticleWindow
        extend Rubbs::Modern::Part

        window :article, :master_detail do
          title      { "#{article.title} (#{article.language})" }
          list_width { [26, cols / 4].max }
          items      { article.sections }
          label      :title
          detail     { |section, width| markdown("# #{section.title}\n\n#{section.markdown}", width) }
          meta       { "#{article.url} · CC BY-SA 4.0" }
          action('&Magyar/English') { other_language(film, article) }
          action('&QR code') { qr article.short_url, title: 'Scan the article' }
        end
      end

      # The approved reviews of a film, or the newest of every film.
      module ReviewsWindow
        extend Rubbs::Modern::Part

        window :reviews, :master_detail do
          empty 'No reviews yet. Rate it and write the first!'
          height(-6)
          title      { caption }
          list_width { [30, cols / 3].max }
          items      { entries }
          label      { |r| every ? "#{r.label[0, 22]} · #{r.stars}/10" : "#{r.handle} · #{r.stars}/10" }
          detail     { |r, width| review_card(r, width) }
          meta       { |r| "#{r.handle} · #{r.date}" }
          on_pick    { |r| open_film(r.film_id) if every }
        end
      end

      # A film on the caller's lists: a box for each.
      module ListsWindow
        extend Rubbs::Modern::Part

        window :lists, :form do
          title { "Lists: #{film.label}" }
          width 56
          hint  'Tick the lists the film is on. Seeing it takes it off the watchlist.'
          field :watchlist, type: :checkbox, label: 'On my watchlist', value: -> { ratings.marked?(identity, film, 'watchlist') }
          field :seen, type: :checkbox, label: 'I have seen it', value: -> { ratings.marked?(identity, film, 'seen') }
          submit_label '&Save'
          on_submit { |values| save_lists(film, values) }
        end
      end

      # The form of a rating: the stars and a review.
      module RateWindow
        extend Rubbs::Modern::Part

        window :rate, :form do
          title { "Rate #{film.label}" }
          width 70
          hint  "#{RatingService::STARS.min} to #{RatingService::STARS.max} stars; a review of up to " \
                "#{RatingService::MAX_REVIEW} characters if you like (an admin reads it first). Alt-S saves."
          field :stars, label: 'Stars', max_length: 2, value: -> { mine&.stars.to_s }
          field :review, type: :textarea, rows: 5, max_length: RatingService::MAX_REVIEW, value: -> { mine&.review || '' }
          submit_label '&Save'
          errors Wording::RATE.except(:ok)
          on_submit do |values|
            result = ratings.rate(film, identity: identity, stars: values[:stars], review: values[:review], caller: caller_key)
            message(Wording::RATE[:ok], title: 'Thanks') if result == :ok
            result
          end
        end
      end
    end
  end
end
