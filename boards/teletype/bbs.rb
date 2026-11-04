# frozen_string_literal: true

require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/logo'
require_relative 'lib/ui/arts'
require_relative 'lib/ui/login'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# One board, two faces: an ANSI terminal gets the modern desktop, a
# Commodore 64 the PETSCII board, both on the same TeletypeBBS. Each face
# opens with the clubhouse's entrance and the logon scans, and closes with
# its lamps going out: that is its goodbye. The accounts are the network's
# (TTG Gate BBS): the entrance asks the name and the password itself
# (UI::Login), and a caller handed on by the gate signed in walks past it.
BBS.board 'Teletype BBS', TeletypeBBS do
  preset  TTG::PRESET
  auth    TTG::AUTH, login: :menu
  goodbye false

  modern do |bbs|
    call { UI::Login.call(self, bbs, UI::Modern::Clubhouse::Entrance.new(session, bbs)) }
    call { UI::Modern::Logon.show(self, bbs) }
    app  UI::Modern::APP
    call { UI::Modern::Clubhouse::Leaving.play(self, bbs) }
  end

  petscii do |bbs|
    call { UI::Login.call(self, bbs, UI::Petscii::Clubhouse::Entrance.new(session, bbs)) }
    face UI::Petscii
  end

  on_session_end { |session, bbs| bbs.end_call(session.session_id) }
end
