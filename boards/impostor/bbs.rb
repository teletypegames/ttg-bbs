# frozen_string_literal: true

require 'bundler/setup'
require_relative 'lib/impostor'

BBS.configure do |c|
  c.flow = Impostor.flow(sessions: Impostor.sessions_store(File.expand_path('data/sessions.csv', __dir__)))
end

BBS.start
