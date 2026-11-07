# frozen_string_literal: true

require_relative 'hunt/screen'

module TTG
  # The Hunt: the network's weekly treasure hunt (rubbs'
  # Rubbs::Common::Hunt), kept on the gate. The hunts are YAML files in the
  # gate's content/hunts, one a week (content/hunts/2026/w46-avian-route.yml);
  # every board offers the caller's hunt in the profile (TTG::Places).
  module Hunt
    # The folder of the hunts: the gate's content/hunts.
    DIR = File.join(TTG::Badges::BOARDS, 'ttg-gate', 'content', 'hunts')

    # Makes the gate's Central serve the hunts of DIR. Returns DIR.
    def self.serve
      Rubbs::Common::Hunt.directory = DIR
      DIR
    end

    # The Central's hunt service.
    def self.proxy = Rubbs.central(Rubbs::Common::Hunt::Service)

    # Shows the caller on +session+ their hunt (+hunt+, a slug; the one in
    # season by default). Returns +nil+.
    def self.open(session, hunt: nil) = Screen.new(session, hunt: hunt).run
  end
end
