# frozen_string_literal: true

module UI
  module Modern
    module Discovery
      # What every screen of Global Discovery on the modern face works with:
      # the caller's session, the lists (Discovery::BrowseService) and the
      # dial rules (Discovery::DialService).
      Context = Data.define(:session, :browse, :dials)
    end
  end
end
