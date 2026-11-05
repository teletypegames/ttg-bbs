# frozen_string_literal: true

require_relative 'wording'
require_relative 'modern/helpers'
require_relative 'modern/games_window'
require_relative 'modern/groups_window'
require_relative 'modern/letters_window'
require_relative 'modern/about_window'
require_relative 'modern/tips_window'
require_relative 'modern/add_tip_window'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): the search
  # in a dialog, lists of games with the card of the one picked on the right,
  # the Wikipedia lead in a scrolling window, the tips of a game in a two-pane
  # window, and a form for a new tip.
  module Modern
    HELP = 'F2 search · F3 random game · F10 menu: years, genres, companies, tips'

    APP = Rubbs::Modern::Application.define do
      theme :synchronet
      helpers { include Helpers }

      command(:search,    'Search…',     key: 'F2') { search }
      command(:random,    'Random game', key: 'F3', hint: 'Random') { random }
      command(:years,     'By &year')    { show(:groups, caption: 'Years', kind: :year, groups: catalog.years) }
      command(:genres,    'By &genre')   { show(:groups, caption: 'Genres', kind: :genre, groups: catalog.genres) }
      command(:companies, 'By &company') { show(:letters) }
      command(:with_tips, 'With &tips')  { with_tips }
      menu 'Games', :search, :random, :separator, :years, :genres, :companies, :with_tips, :separator, :log_off
      help about: Wording::ABOUT, sources: Wording::SOURCES, keys: ['Enter        about the game']
      status { "#{catalog.count} games" }

      desktop do
        art  Rubbs::Common::Text::BlockFont.half_blocks('COMMODEX'), top: 0
        line "─── #{Wording::TAGLINE} ───", top: 4
        line HELP, bottom: 0
        on_show { search }
      end

      parts GamesWindow, GroupsWindow, LettersWindow, AboutWindow, TipsWindow, AddTipWindow
    end
  end
end
