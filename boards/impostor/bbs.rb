# frozen_string_literal: true

require 'bundler/setup'
require_relative 'lib/impostor'

# Two faces on one port: BBS::Terminal asks which terminal is calling, and a
# Commodore 64 gets the same terminal drawn for 40 columns in PETSCII.
sessions = Impostor.sessions_store(File.expand_path('data/sessions.csv', __dir__))

BBS.configure do |c|
  c.flow = BBS::Terminal.flow(title: 'Impostor BBS',
                              modern: Impostor.flow(sessions: sessions),
                              c64: Impostor.flow(sessions: sessions, c64: true))
end

BBS.start
