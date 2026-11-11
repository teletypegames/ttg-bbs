# frozen_string_literal: true

require_relative 'wording'
require_relative 'rows'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen. A cursor main
  # menu, films and people as cursor lists, a film on a page of its own with
  # its actions on one row, a person's films, the Wikipedia articles section
  # by section, the reviews as pages, and lines for the searches and the
  # rating.
  class Petscii < Rubbs::Petscii::Face
    LOGO_COLORS = [YE, YE, OR, OR, DR].freeze
    LOGO_INDENT = [(COLS - Rubbs::Common::Text::BlockFont.width('KINEMA')) / 2, 0].max
    REEL        = "#{DG} [] [] [] [] [] [] [] [] [] [] [] [] []#{LG}".freeze
    QR_COMMAND  = { 'c' => 'qr code' }.freeze
    # The facts a film's page leaves out on 40 columns.
    LEFT_OUT    = %w[Company IMDb].freeze
    RATE_HINT   = "#{RatingService::STARS.min} to #{RatingService::STARS.max} stars, then a review if you like " \
                  '(an admin reads it first). Return alone: back.'.freeze

    title('KINEMA BBS') { "#{catalog.count} films " }

    masthead do
      gap
      art REEL
      gap
      logo 'KINEMA', colors: LOGO_COLORS, indent: LOGO_INDENT
      gap
      art REEL
      gap
      line " #{Wording::TAGLINE}", color: WH
    end

    main_menu do
      item('f', 'search films', 'a title, english or hungarian') { search_films }
      item('p', 'search people', 'actors, directors, writers') { search_people }
      item('d', 'film of the day', -> { catalog.film_of_the_day&.label.to_s[0, 30] }) { film_of_the_day }
      item('t', 'on this day', 'first released on this day') { on_this_day }
      item('e', 'by decade', 'the best known of each decade') { groups('DECADES', catalog.decades, :decade) }
      item('g', 'by genre', 'drama, comedy, western…') { groups('GENRES', catalog.genres, :genre) }
      item('r', 'random film', 'whatever the projector picks') { film(catalog.random&.id) }
      item('b', 'top rated', 'the callers\' best') { rows('TOP RATED', Rows.top(ratings.top)) }
      item('v', 'recent reviews', 'what the callers wrote') { reviews('RECENT REVIEWS', ratings.recent_reviews, every: true) }
      item('m', 'my lists', 'watchlist, seen, my ratings') { mine }
      item('w', 'the lobby wall', 'talk films with the others') { TTG::Wall.open(@session) }
      item('h', 'write to the sysops', 'a wrong fact, an idea') { TTG::Feedback.open(@session) }
      item('i', 'about kinema bbs', 'where the films come from') do
        page('ABOUT KINEMA BBS', [Wording::ABOUT, '', Wording::SOURCES])
      end
      log_off 'the end. see you at the pictures!'
    end

    private

    def search_films = search('SEARCH FILMS', 'a title, english or hungarian.', 'film') { |q| films.search_films(q) }

    def search_people
      search('SEARCH PEOPLE', 'a name: an actor, a director…', 'person', person: true) { |q| films.search_people(q) }
    end

    def search(heading, hint, what, person: false)
      title(heading)
      say("Type #{hint} Return alone: back.", color: GR)
      puts
      query = prompt('search', max: 40)
      return unless query

      found = loading('asking wikidata…') { yield query }
      return alert(Wording.search(found, query, what)) unless found&.any?

      rows("#{heading[7..]}: #{query.upcase}"[0, 30], Rows.hits(found, person: person))
    end

    def film_of_the_day = film(catalog.film_of_the_day&.id)

    def on_this_day
      list = Rows.films(catalog.on_this_day(Date.today))
      rows("ON #{Date.today.strftime('%B %-d').upcase}", list, empty: 'no film of the shelf came out on this day.')
    end

    def groups(heading, list, kind)
      name = ->(n) { kind == :decade ? "#{n}s" : n.to_s }
      each_pick(heading, list, right: list.size.to_s, label: ->((n, count)) { "#{name.call(n)} #{GR}#{count}#{LG}" }) do |(n, _)|
        films = kind == :decade ? catalog.of_decade(n) : catalog.of_genre(n)
        rows(name.call(n).upcase[0, 30], Rows.films(films))
      end
    end

    def mine
      return alert(Wording::RATE[:account]) unless signed_in?

      lists = [['w', 'my watchlist', 'watchlist'], ['s', 'films i have seen', 'seen']]
      each_pick('MY LISTS', [*lists, ['r', 'my ratings', nil]], label: ->((_, label, _)) { label }) do |(_, label, kind)|
        list = kind ? Rows.marks(ratings.list(identity, kind)) : Rows.ratings(ratings.ratings_of(identity))
        rows(label.upcase, list, empty: 'nothing on this list yet.')
      end
    end

    def rows(heading, list, empty: 'nothing here.')
      each_pick(heading, list, empty: empty, right: list.size.to_s, label: :label) do |row|
        row.person? ? person(row.id) : film(row.id)
      end
    end

    # A film's page; its actions read, list its people, rate it, put it on
    # a list.
    def film(id)
      return unless id

      found = loading('asking wikidata…') { films.film(id) }
      fail_with(Wording::NO_ANSWER) unless found
      loop do
        page('FILM', film_lines(found), right: found.year.to_s, wait: false, room: 2)
        case actions(%w[a wiki], %w[c cast], ['r', 'rate/list'], %w[q back])
        when 'a' then article(found)
        when 'c' then people(found)
        when 'r' then rate_or_list(found)
        else return
        end
      end
    end

    def film_lines(film)
      average, count = ratings.score(film)
      facts = Wording.facts(film).reject { |pair| LEFT_OUT.include?(pair.first) }
      facts << ['Callers', Wording.score(average, count)]
      yours = Wording.yours(ratings.mine(identity, film))
      facts << ['Yours', yours] if yours
      [*wrap(film.title).map { |l| " #{WH}#{l}#{LG}" }, '', *facts.flat_map { |k, v| row(k, v) }]
    end

    def row(key, value)
      first, *rest = wrap(value.to_s, WIDTH - 3)
      [" #{CY}#{key.downcase}#{LG}", "   #{first}", *rest.map { |l| "   #{l}" }]
    end

    def people(film)
      rows("PEOPLE: #{film.title.upcase}"[0, 30], Rows.people(film), empty: 'wikidata names nobody.')
    end

    def person(id)
      found = loading('asking wikidata…') { films.person(id) }
      fail_with(Wording::NO_ANSWER) unless found
      lines = [" #{WH}#{found.name}#{LG}", '', *Wording.person_facts(found).flat_map { |k, v| row(k, v) }]
      page('PERSON', lines, wait: false, room: 2)
      return unless actions(%w[f films], %w[q back]) == 'f'

      each_pick(
        found.name.upcase[0, 30],
        Rows.credits(found),
        right: found.credits.size.to_s,
        empty: 'wikidata lists no films of theirs.',
        label: ->(r) { "#{r.label} #{GR}#{r.note}#{LG}" }
      ) do |row|
        film(row.id)
      end
    end

    # The film's article, English when it has one; H switches to the
    # Hungarian.
    def article(film, language = nil)
      fail_with('It has no Wikipedia article.') unless film.wikipedia?
      found = loading('asking wikipedia…') { films.article(film, language) }
      fail_with('Wikipedia did not answer. Try again later.') unless found
      commands = QR_COMMAND.merge(film.huwiki && found.language != 'hu' ? { 'h' => 'magyar' } : {})
      each_pick("#{found.title.upcase[0, 26]} (#{found.language})", found.sections, label: :title, commands: commands) do |picked|
        case picked
        when 'c' then show_qr(found)
        when 'h' then return article(film, 'hu')
        else section(found, picked)
        end
      end
    end

    def section(article, section)
      lines = [" #{WH}#{section.title}#{LG}", '', *markdown(section.markdown)]
      lines += ['', " #{GR}#{article.license.downcase}:#{LG}", *article.url.scan(/.{1,37}/).map { |w| " #{CY}#{w}#{LG}" }]
      page(article.title.upcase[0, 30], lines, room: 1)
    end

    def show_qr(article)
      title('SCAN THE ARTICLE')
      pause if qr(article.short_url)
    end

    # The callers' score, and what to do with it: rate the film, read the
    # reviews, put it on a list or take it off.
    def rate_or_list(film)
      say(" #{GR}callers: #{Wording.score(*ratings.score(film))}#{LG}")
      puts
      case menu(rate_items(film), back: nil)
      when 's' then rate(film)
      when 'v' then reviews("REVIEWS: #{film.title.upcase}"[0, 30], ratings.reviews(film))
      when 'w' then toggle(film, 'watchlist')
      when 'e' then toggle(film, 'seen')
      end
    end

    def rate_items(film)
      on = ->(kind) { ratings.marked?(identity, film, kind) ? 'off' : 'on' }
      [['s', 'my stars and review'], ['v', 'the callers\' reviews'], ['w', "#{on.call('watchlist')} my watchlist"],
       ['e', "#{on.call('seen')} the films i have seen"]].map do |key, label|
        Rubbs::Common::Screens::Selector.item(label, key: key, value: key)
      end
    end

    def rate(film)
      return alert(Wording::RATE[:account]) unless signed_in?

      title("RATE: #{film.title.upcase}"[0, 30])
      say(RATE_HINT, color: GR)
      puts
      stars = number('stars', RatingService::STARS, max: 2)
      return unless stars

      review = review_of(film)
      report(ratings.rate(film, identity: identity, stars: stars, review: review, caller: caller_key), Wording::RATE)
    end

    # The review typed, the old one to start from.
    def review_of(film)
      old = ratings.mine(identity, film)
      edit(
        old&.review.to_s,
        title:       "REVIEW: #{film.title.upcase}"[0, 30],
        single_line: true,
        max:         RatingService::MAX_REVIEW
      ).to_s
    end

    def toggle(film, kind)
      return alert(Wording::RATE[:account]) unless signed_in?

      done = ratings.toggle(identity, film, kind)
      say(done == :added ? "on your #{Wording::LIST_NAMES[kind]}." : "off your #{Wording::LIST_NAMES[kind]}.", color: GR)
      pause
    end

    def reviews(heading, list, every: false)
      lines = list.flat_map do |r|
        head = every ? "#{r.label} #{YE}#{r.stars}/10" : "#{r.handle} #{YE}#{r.stars}/10"
        [" #{CY}#{head}#{GR} #{r.date}#{LG}", *(every ? [" #{GR}by #{r.handle}#{LG}"] : []), *wrap(r.review, WIDTH - 1).map { |l|
          " #{l}"
        }, '']
      end
      lines = [" #{GR}no reviews yet.#{LG}"] if lines.empty?
      page(heading, lines)
    end
  end
end
