# frozen_string_literal: true

# The board itself, whatever terminal a caller has, and the only place that
# reads ENV. The debrief terminal and its code check live in the impostor gem
# (lib/impostor), which another rubbs BBS can mount as a door; the board gives
# it its sessions, kept by the domain (lib/domain). Both faces (lib/ui/modern,
# lib/ui/petscii) work on one instance of it.
class ImpostorBBS
  ROOT = File.expand_path('../..', __dir__)

  attr_reader :sessions

  def initialize(env = ENV)
    path      = File.expand_path(env.fetch('IMPOSTOR_BBS_SESSIONS', 'data/sessions.sqlite3'), ROOT)
    sessions  = SessionRepository.new(path)
    warn "impostor-bbs: #{sessions.count} sessions in #{path}"
    @sessions = SessionService.new(sessions)
  end
end
