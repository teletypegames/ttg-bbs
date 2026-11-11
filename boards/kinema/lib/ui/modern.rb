# frozen_string_literal: true

require_relative 'wording'
require_relative 'rows'
require_relative 'modern/helpers'
require_relative 'modern/windows'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): the
  # searches in dialogs, lists of films and people with the picked one on
  # the right, a film's page in a reader with its buttons, a person's films,
  # the Wikipedia articles section by section, the reviews, the form for a
  # rating, and the network's wall and feedback (ttg-common).
  module Modern
    HELP = 'F2 film · F3 person · F4 film of the day · F5 on this day · F10 menu'

    APP = Rubbs::Modern::Application.define do
      theme :synchronet
      helpers { include Helpers }

      command(:films,    'Search &films…',  key: 'F2', hint: 'Film') { search_films }
      command(:people,   'Search &people…', key: 'F3', hint: 'Person') { search_people }
      command(:daily,    'Film of the &day', key: 'F4', hint: 'Daily') { film_of_the_day }
      command(:today,    '&On this day', key: 'F5', hint: 'Today') { on_this_day }
      command(:decades,  'By d&ecade')  { show(:groups, caption: 'Decades', kind: :decade, groups: decade_groups) }
      command(:genres,   'By &genre')   { show(:groups, caption: 'Genres', kind: :genre, groups: catalog.genres) }
      command(:random,   '&Random film', key: 'F7', hint: 'Random') { open_film(catalog.random&.id) }
      command(:top,      '&Top rated')      { top_rated }
      command(:reviews,  'Recent re&views') { recent_reviews }
      command(:watch,    'My &watchlist')   { my_list('watchlist') }
      command(:seen,     'Films I have &seen') { my_list('seen') }
      command(:rated,    'My ratin&gs') { my_ratings }
      command(:wall,     'The &lobby wall…', hint: 'Wall') { wall }
      command(:feedback, 'Write to the sys&ops…') { feedback }
      menu 'Films',
           :films,
           :people,
           :separator,
           :daily,
           :today,
           :decades,
           :genres,
           :random,
           :separator,
           :top,
           :reviews,
           :separator,
           :log_off
      menu 'Mine', :watch, :seen, :rated, :separator, :wall, :feedback
      help about: Wording::ABOUT, sources: Wording::SOURCES, keys: ['Enter        open the film or person']
      status { "#{catalog.count} films on the shelf" }

      desktop do
        art  Rubbs::Common::Text::BlockFont.half_blocks('KINEMA'), middle: -7
        line Wording::TAGLINE, style: :text, middle: -3
        line HELP, middle: -1
        on_show { film_of_the_day }
      end

      parts Windows::RowsWindow,
            Windows::GroupsWindow,
            Windows::FilmWindow,
            Windows::PersonWindow,
            Windows::ArticleWindow,
            Windows::ReviewsWindow,
            Windows::RateWindow,
            Windows::ListsWindow
    end
  end
end
