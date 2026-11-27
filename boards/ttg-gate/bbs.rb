# frozen_string_literal: true

require 'rubbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# The gate of the Teletype Games boards and of the telnet BBSes of the
# world: on a modern terminal and on a Commodore 64.
board = Rubbs.board 'TTG Gate BBS', TTGGateBBS do
  preset TTG::PRESET
  mouse false
  auth(login: :menu, terminal_login: true, &:accounts)
  central serve:    lambda(&:central_port),
          services: [TTG::Feedback::Service, TTG::Wall::Service, TTG::PrivateMessage::Service, TTG::Badges::Service,
                     Rubbs::Common::Hunt::Service, TTG::Bulletin::Service]
  badges TTG::Badges.load_all(__dir__)
  on_start { |gate| UI::Sysop.offer(gate.accounts) }
  on_start do |gate|
    TTG::Bulletin.source = ->(at) { gate.bulletin(at: at) }
    TTG::Logon.hint = 'T: the whole day on the Today tab.'
  end
  modern { |bbs| call { UI::Modern::Gate.new(session, bbs).run } }
  petscii(goodbye: false) { |bbs| call { UI::Petscii.call(session, bbs) } }
end

board.run! if Rubbs.main?(__FILE__)
