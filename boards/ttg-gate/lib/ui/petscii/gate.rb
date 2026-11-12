# frozen_string_literal: true

require_relative 'chrome'
require_relative 'views/picker'
require_relative 'views/own_view'
require_relative 'views/list_view'
require_relative 'views/menu_view'
require_relative 'views/page_view'
require_relative 'views/sources_view'
require_relative 'views/text_view'
require_relative 'views/today_view'
require_relative 'views/profile_view'
require_relative 'gate/places'
require_relative 'gate/dialing'
require_relative 'gate/input'

module UI
  module Petscii
    # One C64 call of the gate: rubbs' Rubbs::Petscii::Kit::Frame in the
    # gate's Chrome. Our own boards on the OWN tab, Global Discovery's lists,
    # menus and pages on GLOBAL (its sub-menu under the tabs), the caller's
    # profile on PROFILE. CRSR up from the top of a list goes to the
    # sub-menu and the tabs, left and right switch OWN and GLOBAL as the
    # cursor goes, TODAY shows the day (UI::Petscii::Views::TodayView), YOU
    # (the profile, UI::Petscii::Views::ProfileView) opens on RETURN, CRSR
    # down goes back. A yellow
    # sign opens its place from anywhere (a view's own keys first: B on a
    # board's page is its banner). ← or RUN/STOP goes back, Q hangs up.
    class Gate < Rubbs::Petscii::Kit::Frame
      include Places
      include Dialing
      include Input

      # Seconds between two steps of the dialling.
      STEP = 0.12
      INPUT_LABEL = 'Find:'
      INPUT_MAX   = Layout::HINT_WIDTH - INPUT_LABEL.length - 2
      WARNINGS = { dead: ['This board has not answered', 'our calls for 30 days.', 'It may be gone. Dial anyway?'] }.freeze
      REFUSALS = {
        rate:        ['You dialled 10 boards in', '10 minutes. Try again later.'],
        busy:        ['3 callers are on this board', 'already. Try again soon.'],
        not_petscii: ['This board speaks neither', 'PETSCII nor plain ASCII.'],
        not_public:  ['This board is not on the', 'public internet.'],
        unknown:     ['This board is gone from the list.']
      }.freeze
      # The lists of their own: the title, the chip, its colour, the words of
      # an empty one, the BrowseService method.
      FIXED = {
        new:    ['NEW THIS WEEK', '7 days', Canvas::LIGHT_GREY, 'No new board this week.', :new_this_week],
        died:   ['RECENTLY DIED', '30 days', Canvas::LIGHT_RED, 'None died in 30 days.', :recently_died],
        graves: ['GRAVEYARD', 'dead', Canvas::GREY, 'No graves yet.', :graveyard]
      }.freeze
      BANDS = {
        discover: Canvas::LIGHT_GREEN,
        all:      Canvas::LIGHT_GREEN,
        search:   Canvas::WHITE,
        browse:   Canvas::ORANGE,
        new:      Canvas::PURPLE,
        died:     Canvas::LIGHT_RED,
        graves:   Canvas::GREY
      }.freeze

      # [session] the C64 line
      # [boards] our boards with a C64 face (BoardModel), or what answers
      #          them for the caller now (a board of a role shows once they
      #          sign in with it)
      # [browse] Discovery::BrowseService, nil without a catalog
      # [dials]  Discovery::DialService
      # [today]  answers the caller's Herald::Edition (or +nil+)
      def initialize(session, boards:, browse:, dials:, today: -> {})
        super(session, chrome: Chrome::KIT, home: :own, input_label: INPUT_LABEL)
        @boards = boards.respond_to?(:call) ? boards : -> { boards }
        @browse = browse
        @dials  = dials
        @today  = today
      end

      # The search is an action of the sub-menu, not a section.
      def action?(key) = key == :search

      def action(_key) = search

      # Under the tabs: on Today the day, on YOU who is logged in, elsewhere
      # how many boards, and how.
      def top_line(canvas)
        return Chrome.today_line(canvas, view.respond_to?(:edition) ? view.edition : nil) if tab == :today
        return Chrome.account_line(canvas, session.identity) if tab == :account

        Chrome.own_line(canvas, @boards.call.size)
      end
    end
  end
end
