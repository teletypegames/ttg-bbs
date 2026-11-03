# frozen_string_literal: true

# The board itself, whatever terminal a caller has. The debrief terminal and
# its code check live in the impostor gem (lib/impostor), which another rubbs
# BBS can mount as a door; the board gives it the record of its calls, kept
# by the domain (lib/domain). Both faces work on one instance of it.
class ImpostorBBS
  include BBS::Domain

  path :sessions, 'data/sessions.sqlite3'

  service(:debriefs) do
    BBS.log('sessions', "kept in #{sessions}")
    SessionService.new(SessionRepository.new(sessions).open!)
  end
end
