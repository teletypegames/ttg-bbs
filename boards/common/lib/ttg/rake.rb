# frozen_string_literal: true

require 'rubbs/rake'
require_relative 'check'

# The house rules of the Teletype Games boards join Rubbs::Common::Board::Check, and
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
      desc 'Formats the code by the shared RuboCop rules (rubocop -a): the layout of every Ruby file'
      task :format do
        sh 'bundle', 'exec', 'rubocop', '--autocorrect', '--format', 'quiet' do |ok, _|
          puts ok ? 'ttg:format: in shape' : 'ttg:format: formatted; what RuboCop cannot fix is listed by bundle exec rubocop'
        end
      end
    end
  end
end
