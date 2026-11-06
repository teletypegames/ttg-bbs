# frozen_string_literal: true

module TTG
  # The places every TTG board offers in the caller's profile
  # (Rubbs::Common::Auth::Profile.extra), the same on every board: Feedback
  # (TTG::Feedback) and the Wall (TTG::Wall), on a board tied to the Central.
  # A board puts them in its own menus too; these are there even before it
  # does.
  module Places
    # Whether the board is tied to the Central (Rubbs.board's +central+).
    CENTRAL = ->(_session) { !Rubbs.config.central.nil? }

    # Adds the places to the profile of every caller of this process.
    def self.offer
      Rubbs::Common::Auth::Profile.extra(:feedback, 'Feedback', hotkey: 'f', if: CENTRAL) { |session| Feedback.open(session) }
      Rubbs::Common::Auth::Profile.extra(:wall, 'The Wall', hotkey: 'w', if: CENTRAL) { |session| Wall.open(session) }
    end
  end
end
