# frozen_string_literal: true

# Lets another rubbs BBS mount the debrief terminal as a door:
#   gem 'impostor', git: 'https://git.teletypegames.org/bbs/impostor-bbs.git'
#   require 'impostor'   # => Impostor::Modern.flow(sessions:), Impostor::Petscii.flow(sessions:)
Gem::Specification.new do |s|
  s.name     = 'impostor'
  s.version  = '0.4.0'
  s.summary  = 'The debrief terminal of Definitely not an Impostor as a rubbs flow'
  s.authors  = ['Teletype Games']
  s.files    = Dir['lib/impostor.rb', 'lib/impostor/**/*.rb', 'screens/**/*.erb']
  s.require_paths = ['lib']
  s.required_ruby_version = '>= 3.1'
  s.add_dependency 'bbs', '>= 0.16.1'
  s.metadata['rubygems_mfa_required'] = 'true'
end
