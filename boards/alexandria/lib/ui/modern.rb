# frozen_string_literal: true

require_relative 'modern/pharos'
require_relative 'modern/helpers'
require_relative 'modern/results_window'
require_relative 'modern/article_window'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): the
  # Pharos on the desktop, the search in a dialog, the results and the
  # article in two-pane windows, the network's feedback and wall (ttg-common).
  module Modern
    ABOUT = 'Alexandria BBS — Wikipedia on a telnet line, from Teletype Games, powered by rubbs. ' \
            'Type a title: the article of that title opens at once, otherwise the search results. ' \
            'An article opens with its sections on the left. ' \
            "The text is Wikipedia's, under CC BY-SA; the address is under each article."
    HELP  = 'F2 search · F3 random article · F4 language · Alt-X log off'

    APP = Rubbs::Modern::Application.define do
      theme :synchronet
      helpers { include Helpers }
      init { context[:lang] ||= articles.languages.first }

      command(:search,   'Search…',        key: 'F2') { search }
      command(:random,   'Random article', key: 'F3', hint: 'Random') { random }
      command(:language, 'Language…',      key: 'F4') { switch_language }
      command(:wall,     'The wall…', hint: 'Wall') { wall }
      command(:feedback, 'Write to the librarians…', hint: 'Feedback') { feedback }
      menu 'Wiki', :search, :random, :language, :separator, :wall, :feedback, :separator, :log_off
      help about: ABOUT

      status { "#{lang}.wikipedia.org" }

      desktop do
        widget(height: Pharos::HEIGHT, middle: -12) { Pharos.new }
        line HELP, middle: 4
        on_show { search }
      end

      parts ResultsWindow, ArticleWindow
    end
  end
end
