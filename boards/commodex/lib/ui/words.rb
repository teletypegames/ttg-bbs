# frozen_string_literal: true

module UI
  # What both faces tell the caller: a game's facts, and the words for the
  # answers of the services.
  module Words
    TAGLINE = 'the Commodore 64 game compendium'

    ABOUT = 'Commodex BBS — the Commodore 64 game compendium of Teletype Games: search titles, read about ' \
            'them, and trade cheats and tips. The catalog is Wikidata\'s (CC0), the stories are Wikipedia\'s ' \
            '(CC BY-SA 4.0), the tips are the callers\'.'

    SOURCES = 'The games, years, companies and genres come from Wikidata (wikidata.org), under CC0, refreshed ' \
              'every week: every item on the Commodore 64 platform that is a video game. Wikidata is edited by ' \
              'anyone, so a game may be missing or a fact wrong; fix it there and it shows here. The about pages ' \
              'are the leads of the English Wikipedia articles, under CC BY-SA 4.0, with the article\'s address. ' \
              'The tips are sent by callers and read by an admin before they show.'

    TIP_RULES = "One cheat, POKE or tip, up to #{TipService::MAX_TEXT} characters. An admin reads it before it " \
                'shows on the board.'.freeze

    # The facts of +game+ as [label, text] pairs, the empty ones left out.
    def self.facts(game)
      [['Year', game.year&.to_s], ['Publisher', game.publishers], ['Developer', game.developers],
       ['Design', game.designers], ['Music', game.composers], ['Genre', game.genres], ['Modes', game.modes],
       ['Series', game.series]].filter_map do |label, value|
        text = Array(value).join(', ')
        [label, text] unless text.empty?
      end
    end

    def self.tips(count) = count.zero? ? 'no tips yet' : "#{count} tip#{'s' unless count == 1}"

    def self.search(result, query)
      case result
      when :too_short then "Type at least #{CatalogService::MIN_QUERY} letters or digits."
      when [] then "No game title holds \"#{query}\"."
      end
    end

    def self.about(result)
      case result
      when :no_article then 'Wikipedia has no English article on this game.'
      when :unavailable then 'Wikipedia did not answer. Try again later.'
      end
    end

    def self.tip(result)
      case result
      when :ok           then 'Thanks! Your tip waits for an admin, and shows once approved.'
      when :empty        then 'Write the tip first.'
      when :too_long     then "A tip is at most #{TipService::MAX_TEXT} characters."
      when :rate_limited then "That is enough tips for now: #{TipService::PER_SESSION} a call, one every " \
                              "#{TipService::GAP} seconds."
      else 'The tip could not be saved. Try again later.'
      end
    end
  end
end
