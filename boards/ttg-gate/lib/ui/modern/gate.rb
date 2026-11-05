# frozen_string_literal: true

module UI
  module Modern
    # The pages of the modern face: the two sides of the chooser (our own
    # boards and Global Discovery), each keeping its place while the other
    # is shown, and the search line at the bottom of the screen while it is
    # read.
    class Gate < BBS::Pages
      include Style
      include Prompt

      # The tabs of the chooser in order; TAB and the arrows go round them.
      SIDES = %i[own discovery profile].freeze

      def initialize(session, bbs)
        super(session, face: :modern)
        @sides = {
          own:       OwnServers.new(bbs.directory.boards),
          discovery: Discovery::Home.new(Discovery::Context.new(session: session, browse: bbs.browse, dials: bbs.dials))
        }
        @side = :own
      end

      # Runs the chooser from our own boards (or on from where it was) until
      # the caller hangs up.
      def run(page = (@sides[:own] if stack.empty?)) = super

      # Turns to the next tab (+step+ 1) or the one before (-1). The profile
      # (BBS::Auth::Profile, with SysOp for a sysop) takes the screen, and
      # from it the caller comes back to the tab they left.
      def switch(step = 1)
        side = SIDES[(SIDES.index(@side) + step) % SIDES.size]
        return profile if side == :profile

        @side = side
        reset(@sides[@side])
      end

      # The caller's profile, from any tab; back where they were after it.
      def profile
        hand_over { BBS::Auth::Profile.run(session) }
        reset(@sides[@side])
      end

      def draw(frame)
        super
        prompt(frame) if line
      end
    end
  end
end
