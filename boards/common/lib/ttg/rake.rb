# frozen_string_literal: true

require 'bbs/rake'
require_relative 'check'

# The house rules of the Teletype Games boards join BBS::Check: a board's
# Rakefile loads them after rubbs' tasks.
#
#   require 'bbs/rake'
#   require 'ttg/rake'
#   BBS::Rake.board
module TTG
  # The rake side of ttg-common: loading this file is all it takes.
  module Rake
  end
end
