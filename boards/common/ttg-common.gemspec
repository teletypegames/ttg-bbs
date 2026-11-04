# frozen_string_literal: true

# What the TTG boards share beyond rubbs: the Teletype Games logo now, more
# later. A board pulls it from git:
#   gem 'ttg-common', git: 'https://git.teletypegames.org/bbs/common.git'
#   require 'ttg/common'
Gem::Specification.new do |s|
  s.name     = 'ttg-common'
  s.version  = '0.6.0'
  s.summary  = 'The shared parts of the Teletype Games BBS boards, on rubbs'
  s.authors  = ['Teletype Games']
  s.license  = 'MIT'
  s.files    = Dir['lib/**/*.{rb,yml}', 'lib/ttg/board/*']
  s.require_paths = ['lib']
  s.required_ruby_version = '>= 3.2'
  s.add_dependency 'bbs', '>= 2.2'
  s.metadata['rubygems_mfa_required'] = 'true'
end
