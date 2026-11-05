# frozen_string_literal: true

module UI
  module Modern
    # The look of the modern face, rubbs' BBS::Kit::Modern set up for the
    # gate: the palette of bbsweb, the gate's logo and tabs, Global
    # Discovery's top line; and the state marks of the catalog's boards.
    module Style
      include BBS::Kit::Modern::Style

      # The colour of a board's state mark.
      STATE_COLORS = { 'online' => GREEN, 'flaky' => YELLOW, 'down' => RED, 'dead' => DIM, 'unknown' => TEXT }.freeze

      LOGO = [
        ' _____ _____ ___    ___   _ _____ ___',
        '|_   _|_   _/ __|  / __| /_\\_   _| __|',
        '  | |   | || (_ | | (_ |/ _ \\| | | _|',
        '  |_|   |_| \\___|  \\___/_/ \\_\\_| |___|'
      ].freeze

      TABS = { own: 'OWN SERVERS', discovery: 'GLOBAL DISCOVERY', profile: 'PROFILE' }.freeze

      # The gate's look (BBS::Kit::Modern::Look).
      LOOK = BBS::Kit::Modern::Look.new(logo: LOGO, tabs: TABS, crumb: 'GLOBAL DISCOVERY')

      def mark(listing) = "#{STATE_COLORS.fetch(listing.state, TEXT)}#{listing.mark}#{RESET}"
    end

    # A screen of the modern face (BBS::Kit::Modern::Screen) with the gate's
    # helpers.
    class Screen < BBS::Kit::Modern::Screen
      include Style
    end

    # A screen of given lines: a question, a notice, until a key.
    Lines = BBS::Kit::Modern::Lines
  end
end
