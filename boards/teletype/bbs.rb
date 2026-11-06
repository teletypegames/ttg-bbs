# frozen_string_literal: true

require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/logo'
require_relative 'lib/ui/arts'
require_relative 'lib/ui/login'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# One board, two faces: an ANSI terminal gets the modern desktop, a
# Commodore 64 the PETSCII board, both on the same TeletypeBBS. The splash
# asks Login, Register or Guest on the accounts of the network (TTG Gate
# BBS), and a caller handed on by the gate signed in walks past it; each
# face closes with its lamps going out: that is its goodbye. A modern
# terminal that never reported its size is a scanner, not listed.
Rubbs.board 'Teletype BBS', TeletypeBBS do
  preset  TTG::PRESET
  central TTG::CENTRAL
  auth    login: :menu
  goodbye false

  modern do |bbs|
    call { UI::Login.call(self, bbs, listed: session.naws_reported?) }
    app  UI::Modern::APP
    call { UI::Modern::Clubhouse::Leaving.play(self, bbs) }
  end

  petscii do |bbs|
    call { UI::Login.call(self, bbs, listed: true) }
    face UI::Petscii
  end

  on_session_end { |session, bbs| bbs.end_call(session.session_id) }
end
