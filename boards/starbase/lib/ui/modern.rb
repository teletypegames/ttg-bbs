# frozen_string_literal: true

require_relative 'card'
require_relative 'modern/helpers'
require_relative 'modern/series_window'
require_relative 'modern/episodes_window'
require_relative 'modern/results_window'
require_relative 'modern/article_window'

module UI
  # The library on a modern terminal (ANSI colours, UTF-8, a mouse): the
  # series, a series' episodes and the episodes aired on this day in two-pane
  # windows, Memory Alpha's articles with their sections on the left.
  module Modern
    ABOUT = 'Starbase BBS — a Star Trek library on a telnet line, from Teletype Games, powered by rubbs. ' \
            'Every series and film with its episodes, the day each first aired, its directors and writers ' \
            '(Wikidata, CC0), and the articles of Memory Alpha, the fan wiki (CC BY-NC), read section by ' \
            'section. Star Trek is a trademark of Paramount; this is a fan library, not affiliated with it.'
    TAGLINE = 'A Star Trek library: every series, every episode, and Memory Alpha to read.'
    HELP    = 'F2 series · F3 on this day · F4 library computer · F7 random article · Alt-X log off'

    APP = Rubbs::Modern::Application.define do
      theme :synchronet
      helpers { include Helpers }

      command(:series, 'Series',            key: 'F2') { show(:series) }
      command(:today,  'On this day',       key: 'F3', hint: 'Today') { today }
      command(:search, 'Library computer…', key: 'F4', hint: 'Search') { search }
      command(:random, 'Random article',    key: 'F7', hint: 'Random') { random }
      menu 'Starbase', :series, :today, :search, :random, :separator, :log_off
      help about: ABOUT
      status { "#{catalog.size} episodes" }

      desktop do
        art  Rubbs::Common::Text::BlockFont.half_blocks('STARBASE'), middle: -7
        line TAGLINE, style: :text, middle: -3
        line HELP, middle: -1
        on_show { show(:series) }
      end

      parts SeriesWindow, EpisodesWindow, ResultsWindow, ArticleWindow
    end
  end
end
