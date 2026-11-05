# frozen_string_literal: true

module UI
  module Modern
    # The look of the modern face, rubbs' Rubbs::Modern::Kit set up for the
    # gate: the palette of bbsweb, the gate's logo and tabs, Global
    # Discovery's top line; and the state marks of the catalog's boards.
    module Style
      include Rubbs::Modern::Kit::Style

      # The colour of a board's state mark.
      STATE_COLORS = { 'online' => GREEN, 'flaky' => YELLOW, 'down' => RED, 'dead' => DIM, 'unknown' => TEXT }.freeze

      LOGO = [
        ' _____ _____ ___    ___   _ _____ ___',
        '|_   _|_   _/ __|  / __| /_\\_   _| __|',
        '  | |   | || (_ | | (_ |/ _ \\| | | _|',
        '  |_|   |_| \\___|  \\___/_/ \\_\\_| |___|'
      ].freeze

      TABS = { own: 'OWN SERVERS', discovery: 'GLOBAL DISCOVERY', profile: 'PROFILE' }.freeze

      # The gate's look (Rubbs::Modern::Kit::Look).
      LOOK = Rubbs::Modern::Kit::Look.new(logo: LOGO, tabs: TABS, crumb: 'GLOBAL DISCOVERY')

      def mark(listing) = "#{STATE_COLORS.fetch(listing.state, TEXT)}#{listing.mark}#{RESET}"
    end

    # A screen of the modern face (Rubbs::Modern::Kit::Screen) with the gate's
    # helpers.
    class Screen < Rubbs::Modern::Kit::Screen
      include Style
    end

    # A screen of given lines: a question, a notice, until a key.
    Lines = Rubbs::Modern::Kit::Lines
  end
end
