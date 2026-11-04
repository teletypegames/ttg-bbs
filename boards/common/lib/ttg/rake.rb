# frozen_string_literal: true

require 'bbs/rake'
require_relative 'check'
require_relative 'sync'

# The house rules of the Teletype Games boards join BBS::Check, and
# <tt>rake ttg:sync</tt> writes the files every board shares (TTG::Sync): a
# board's Rakefile loads them after rubbs' tasks.
#
#   require 'bbs/rake'
#   require 'ttg/rake'
#   BBS::Rake.board
module TTG
  # The rake side of ttg-common: loading this file is all it takes.
  module Rake
    extend ::Rake::DSL

    namespace :ttg do
      desc 'Writes the Dockerfile, .dockerignore and .woodpecker.yaml from ttg-common (TTG::Sync)'
      task :sync do
        written = TTG::Sync.run(Dir.pwd)
        puts written.empty? ? 'ttg:sync: the shared files are as in ttg-common' : "ttg:sync: wrote #{written.join(', ')}"
      end
    end
  end
end
