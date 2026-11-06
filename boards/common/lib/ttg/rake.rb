# frozen_string_literal: true

require 'rubbs/rake'
require_relative 'check'
require_relative 'sync'

# The house rules of the Teletype Games boards join Rubbs::Common::Board::Check,
# <tt>rake ttg:sync</tt> writes the files every board shares (TTG::Sync) and
# <tt>rake ttg:format</tt> formats the code by the shared RuboCop rules: a
# board's Rakefile loads them after rubbs' tasks.
#
#   require 'rubbs/rake'
#   require 'ttg/rake'
#   Rubbs::Rake.board
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

      desc 'Formats the code by the shared RuboCop rules (rubocop -a): the layout of every Ruby file'
      task :format do
        sh 'bundle', 'exec', 'rubocop', '--autocorrect', '--format', 'quiet' do |ok, _|
          puts ok ? 'ttg:format: in shape' : 'ttg:format: formatted; what RuboCop cannot fix is listed by bundle exec rubocop'
        end
      end
    end
  end
end
