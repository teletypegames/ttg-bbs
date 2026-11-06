# frozen_string_literal: true

require 'rubbs'

# The shared parts of the Teletype Games boards, on rubbs (the +bbs+ gem):
# what more than one board needs and is not general enough for rubbs
# itself. Each part is a module of its own under TTG, in its own file.
#
#   require 'ttg/common'
#   Rubbs.board('Teletype BBS', TeletypeBBS) { preset TTG::PRESET; … }
module TTG
end

require_relative 'logo'
require_relative 'preset'
require_relative 'central'
require_relative 'auth'
require_relative 'narrative'
require_relative 'screen'
require_relative 'feedback'
require_relative 'wall'
require_relative 'private_message'
require_relative 'places'

TTG::Places.offer
