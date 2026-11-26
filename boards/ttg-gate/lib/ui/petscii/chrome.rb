# frozen_string_literal: true

require_relative 'layout'

module UI
  module Petscii
    # The frame of the gate's C64 screens, rubbs' Rubbs::Petscii::Kit::Chrome
    # set up for the gate: the menu bar (TTG, then OWN, GLOBAL, TODAY,
    # TROPHY with its P lit, and YOU, the profile; two cells between them,
    # so the five fit the 39 cells a C64 prints), Global Discovery's sub-menu under it, the hotkeys, and the
    # line under the tabs on Own Servers.
    module Chrome
      # The gate's chrome.
      KIT = Rubbs::Petscii::Kit::Chrome.new(
        title:    'TTG',
        places:   [[:own, 'OWN'], [:discover, 'GLOBAL'], [:today, 'TODAY'], [:trophy, 'TROPHY', 3], [:account, 'YOU']],
        gap:      2,
        menu:     [[:search, '/Find', 0], [:browse, 'Browse', 0], [:new, 'New', 0], [:random, 'Random', 0],
                   [:sources, 'Sources', 0]],
        menu_tab: :discover,
        under:    { all: :browse, software: :browse, country: :browse, network: :browse },
        # The places of the bar (O, G, T, P for the Trophy Room, Y; D for
        # Discovery, A for the account as before), the axes of Browse (soft_w_are, _c_ountry,
        # networ_k_), U for the Sources as before, Help and Quit; the
        # sub-menu's signs are added.
        hotkeys:  {
          'o' => :own,
          'd' => :discover,
          'g' => :discover,
          'w' => :software,
          'c' => :country,
          'k' => :network,
          'u' => :sources,
          't' => :today,
          'p' => :trophy,
          'y' => :account,
          'h' => :help,
          'a' => :account,
          'q' => :quit
        }
      )
      TITLE      = KIT.title
      BAR        = KIT.colors[:bar]
      LIT        = KIT.colors[:lit]
      KEY        = KIT.colors[:key]
      CURSOR     = KIT.colors[:cursor]
      PLACES_BAR = KIT.places
      MENU       = KIT.menu
      UNDER      = KIT.under
      HOTKEYS    = KIT.hotkeys

      module_function

      # The line under the tabs on Own Servers: how many boards, and how.
      def own_line(canvas, count)
        KIT.line(canvas, [[count.to_s, Canvas::WHITE], [' boards  ', Canvas::GREY], ['RETURN', Canvas::YELLOW],
                          [' dials  ', Canvas::GREY], ['H', Canvas::YELLOW], [' Help', Canvas::GREY]])
      end

      # The line under the tabs on YOU: the caller's name, or how to get one.
      def account_line(canvas, identity)
        return KIT.line(canvas, [['One account for every board', Canvas::GREY]]) unless identity.signed_in?

        KIT.line(canvas, [['Logged in as ', Canvas::GREY], [Layout.plain(identity.name.to_s)[0, 24], Canvas::WHITE]])
      end

      # The line under the tabs on the Trophy Room: what it is, and when its
      # numbers came.
      def trophy_line(canvas, room)
        return KIT.line(canvas, [['Our proudest numbers', Canvas::GREY]]) unless room&.ready?

        KIT.line(canvas, [['Our proudest numbers, ', Canvas::GREY], ['all time', Canvas::YELLOW]])
      end

      # The line under the tabs on Today: the date and the name days.
      def today_line(canvas, edition)
        return KIT.line(canvas, [['Today', Canvas::GREY]]) unless edition

        day = edition.day
        names = day.namedays.first(2).join(', ')
        KIT.line(canvas, [[day.date.strftime('%a %-d %b  '), Canvas::WHITE], [Layout.plain(names)[0, 26], Canvas::YELLOW]])
      end

      # The menu bar (Rubbs::Petscii::Kit::Chrome#bar).
      def bar(canvas, active:, cursor: nil) = KIT.bar(canvas, active: active, cursor: cursor)

      # The sub-menu (Rubbs::Petscii::Kit::Chrome#menu_bar).
      def menu(canvas, lit:, focused:) = KIT.menu_bar(canvas, lit: lit, focused: focused)

      # The hint bar (Rubbs::Petscii::Kit::Chrome#hint).
      def hint(canvas, parts) = KIT.hint(canvas, parts)
    end
  end
end
