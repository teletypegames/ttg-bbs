# frozen_string_literal: true

require_relative 'logo'
require_relative 'words'
require_relative 'modern/helpers'
require_relative 'modern/card'
require_relative 'modern/pane'
require_relative 'modern/games_window'
require_relative 'modern/groups_window'
require_relative 'modern/letters_window'
require_relative 'modern/about_window'
require_relative 'modern/tips_window'
require_relative 'modern/add_tip_window'
require_relative 'modern/menu'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): a desktop
  # under a menubar, the search in a dialog, lists of games with the card of
  # the one picked on the right, the Wikipedia lead in a scrolling window,
  # the tips of a game in a two-pane window, and a form for a new tip.
  module Modern
    PARTS = [GamesWindow, GroupsWindow, LettersWindow, AboutWindow, TipsWindow, AddTipWindow, Menu].freeze

    def self.flow(bbs)
      app = application(bbs)
      BBS::Flow.define do
        call do |ctx, runner|
          app.run(session: runner.session, session_id: ctx[:session_id], context: ctx)
          nil
        end
        call do |_ctx, runner|
          BBS::Goodbye.modern(runner, title: 'Commodex BBS',
                                      note: 'Games from wikidata.org (CC0), stories from wikipedia.org (CC BY-SA).')
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    def self.application(bbs)
      BBS::Application.define do
        theme BBS::Theme.synchronet
        services bbs.services
        helpers { include Helpers }
        PARTS.each { |part| part.install(self) }
      end
    end
  end
end
