# frozen_string_literal: true

# The board itself, whatever terminal a caller has. The debrief terminal and
# its rules live in the impostor gem (lib/impostor), which the Teletype BBS
# mounts as a door too; the board only gives it a sessions store. Both faces
# (lib/ui/modern, lib/ui/petscii) work on one instance of it.
class ImpostorBBS
  ROOT = File.expand_path('../..', __dir__)

  attr_reader :sessions

  def initialize
    @sessions = Impostor.sessions_store(File.expand_path(ENV.fetch('IMPOSTOR_BBS_SESSIONS', 'data/sessions.csv'), ROOT))
  end

  # The services by name.
  def services = { sessions: @sessions }
end
