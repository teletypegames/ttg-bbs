# frozen_string_literal: true

module UI
  module Modern
    # The tabs of the modern face, rubbs' Rubbs::Modern::Kit::Tabs in the
    # gate's look: our own boards, Global Discovery and Today, each keeping its
    # place while the other is shown, and the caller's profile
    # (Rubbs::Common::Auth::Profile, with SysOp for a sysop), the walls of every
    # board (TTG::Wall) and the feedback box (TTG::Feedback), which take the
    # screen and bring the caller back to the tab they left.
    class Gate < Rubbs::Modern::Kit::Tabs
      def initialize(session, bbs)
        ctx   = Discovery::Context.new(session: session, browse: bbs.browse, dials: bbs.dials)
        today = UI.today(session, bbs)
        super(
          session,
          look:    Style::LOOK,
          sides:   {
            own:       OwnServers.new(bbs.directory.boards, today: today),
            discovery: Discovery::Home.new(ctx),
            today:     Today.new(today, ctx: ctx)
          },
          actions: {
            wall:     ->(tabs) { tabs.hand_over { TTG::Wall.open(tabs.session, board: nil) } },
            feedback: ->(tabs) { tabs.hand_over { TTG::Feedback.open(tabs.session) } },
            profile:  ->(tabs) { tabs.hand_over { Rubbs::Common::Auth::Profile.run(tabs.session) } }
          }
        )
      end

      # The caller's profile, from any tab.
      def profile = open_tab(:profile)
    end
  end
end
