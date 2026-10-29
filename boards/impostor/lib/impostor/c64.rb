# frozen_string_literal: true

module Impostor
  # The terminal on a Commodore 64: the same flow on a PETSCII line, its
  # screens drawn for 40 columns.
  module C64
    SCREENS = File.join(Impostor::SCREENS, 'c64')

    def self.flow(sessions:) = Impostor.debrief(sessions: sessions, screens_dir: SCREENS)
  end
end
