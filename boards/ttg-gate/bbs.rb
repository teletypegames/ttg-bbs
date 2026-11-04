# frozen_string_literal: true

require 'bbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# The gate of the Teletype Games boards and of the telnet BBSes of the
# world: on a modern terminal and on a Commodore 64.
BBS.board 'TTG Gate BBS', TTGGateBBS do
  preset  TTG::PRESET
  mouse   false
  auth(login: :menu, &:accounts)
  on_start(&:serve_accounts)
  modern { |bbs| call { UI::Modern::Gate.new(session, bbs).run } }
  petscii(goodbye: false) { |bbs| call { UI::Petscii.call(session, bbs) } }
end
