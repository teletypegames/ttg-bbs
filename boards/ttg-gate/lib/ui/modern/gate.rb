# frozen_string_literal: true

module UI
  module Modern
    # The tabs of the modern face, rubbs' Rubbs::Modern::Kit::Tabs in the
    # gate's look: our own boards, Global Discovery, Today and the caller's
    # profile (ProfileTab), each keeping its place while another is shown, TAB
    # going round them. The walls of every board (TTG::Wall), the feedback box
    # (TTG::Feedback) and The Hunt (TTG::Hunt) are no tabs: W, F and H (or the
    # profile's list) open them, they take the screen and bring the caller
    # back to the tab they left.
    class Gate < Rubbs::Modern::Kit::Tabs
      # The places that take the screen, by tab key.
      ACTIONS = {
        wall:     ->(tabs) { tabs.hand_over { TTG::Wall.open(tabs.session, board: nil) } },
        feedback: ->(tabs) { tabs.hand_over { TTG::Feedback.open(tabs.session) } },
        hunt:     ->(tabs) { tabs.hand_over { TTG::Hunt.open(tabs.session) } }
      }.freeze

      def initialize(session, bbs)
        ctx   = Discovery::Context.new(session: session, browse: bbs.browse, dials: bbs.dials)
        today = UI.today(session, bbs)
        super(
          session,
          look:    Style::LOOK,
          sides:   {
            own:       OwnServers.new(bbs.directory.boards, today: today),
            discovery: Discovery::Home.new(ctx),
            today:     Today.new(today, ctx: ctx),
            profile:   ProfileTab.new
          },
          actions: ACTIONS
        )
      end

      # The caller's profile, from any tab.
      def profile = open_tab(:profile)
    end
  end
end
