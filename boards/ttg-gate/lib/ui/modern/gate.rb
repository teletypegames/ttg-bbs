# frozen_string_literal: true

module UI
  module Modern
    # The tabs of the modern face, rubbs' BBS::Kit::Modern::Tabs in the
    # gate's look: our own boards and Global Discovery, each keeping its
    # place while the other is shown, and the caller's profile
    # (BBS::Auth::Profile, with SysOp for a sysop), which takes the screen
    # and brings the caller back to the tab they left.
    class Gate < BBS::Kit::Modern::Tabs
      def initialize(session, bbs)
        super(
          session,
          look:    Style::LOOK,
          sides:   {
            own:       OwnServers.new(bbs.directory.boards),
            discovery: Discovery::Home.new(Discovery::Context.new(session: session, browse: bbs.browse, dials: bbs.dials))
          },
          actions: { profile: ->(tabs) { tabs.hand_over { BBS::Auth::Profile.run(tabs.session) } } }
        )
      end

      # The caller's profile, from any tab.
      def profile = open_tab(:profile)
    end
  end
end
