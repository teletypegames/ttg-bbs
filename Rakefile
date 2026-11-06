# frozen_string_literal: true

require 'rubbs/rake'

# rake test / rake bbs:check / rake: every folder of boards/, each in a process
# of its own (BOARDS=feedia,common chooses).
Rubbs::Rake.multi(root: 'boards')

desc 'RuboCop in every folder of boards/ by its own .rubocop.yml, and on the root files'
task :rubocop do
  failed = Rubbs::Rake.folders('boards', ENV.fetch('BOARDS', '')).reject do |dir|
    puts "==> #{File.basename(dir)}: rubocop"
    system('bundle', 'exec', 'rubocop', chdir: dir)
  end
  failed << 'root' unless system('bundle', 'exec', 'rubocop', 'bbs.rb', 'Rakefile', 'Gemfile')
  abort "rubocop failed in: #{failed.map { |dir| File.basename(dir) }.join(', ')}" if failed.any?
end
