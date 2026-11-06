# frozen_string_literal: true

module Impostor
  # The terminal on a modern terminal (ANSI/xterm): its screens drawn for
  # 80 columns.
  module Modern
    SCREENS = File.join(Impostor::SCREENS, 'modern')

    def self.flow(sessions:) = Impostor.debrief(sessions: sessions, screens_dir: SCREENS)
  end
end
