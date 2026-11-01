# frozen_string_literal: true

module UI
  module Modern
    # A list of games, the card of the one picked on the right; its buttons
    # open the about page, the tips, and the form for a tip.
    module GamesWindow
      ACTIONS = { 'A&bout' => :about, '&Tips' => :tips, 'A&dd a tip' => :add_tip }.freeze

      module_function

      def install(app)
        app.window(:games, type: :master_detail) { |w| configure(w) }
      end

      def configure(w)
        Pane.size(w)
        w.items         { |ctx| ctx[:games] }
        w.item_label    { |g, _ctx| g.label }
        w.empty_message 'No games here.'
        w.render_detail { |g, width, ctx| Card.lines(ctx[:app], g, width) }
        w.bottom_meta   { |g, _ctx| g.id }
        w.on_activate   { |g, _window, ctx| ctx[:app].about(g) }
        ACTIONS.each { |label, helper| action(w, label, helper) }
      end

      # A button that calls +helper+ of the app with the game picked.
      def action(w, label, helper)
        w.action(label: label) do |win, ctx|
          game = ctx[:app].selected(win)
          ctx[:app].public_send(helper, game) if game
          :keep
        end
      end
    end
  end
end
