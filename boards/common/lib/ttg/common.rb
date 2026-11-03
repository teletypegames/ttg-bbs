# frozen_string_literal: true

require 'bbs'

# The shared parts of the Teletype Games boards, on rubbs (the +bbs+ gem):
# what more than one board needs and is not general enough for rubbs
# itself. Each part is a module of its own under TTG, in its own file.
#
#   require 'ttg/common'
#   BBS::Terminal.flow(title: 'Teletype BBS', modern: m, petscii: p, splash: TTG::Logo.splash)
module TTG
end

require_relative 'logo'
