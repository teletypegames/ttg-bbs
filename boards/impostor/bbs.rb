# frozen_string_literal: true

require 'bundler/setup'
require 'bbs'
require_relative 'lib/code_generator'

BBS.configure do |c|
  c.screens_dir = File.expand_path('screens', __dir__)

  sessions = BBS::Store.new(
    path:    File.expand_path('data/sessions.csv', __dir__),
    headers: %w[session_id timestamp player_name code feedback email]
  )

  c.flow = BBS::Flow.define do
    screen :welcome

    ask :player_name, prompt: "Player Name", transform: :upcase
    ask :code,        prompt: "Code"
    persist :player_name, :code, store: sessions

    pause "Verifying identity...", seconds: 1.2

    gate denied: "Access denied. Code mismatch." do |ctx|
      BBS::CodeGenerator.decrypt(ctx[:code]) == ctx[:player_name][0, BBS::CodeGenerator::NAME_LEN]
    end

    confirm "Norman, is that you?", denied: "Very well. Goodbye." do
      screen :congrats

      ask :feedback, prompt: "Any feedback about the game?"
      persist :feedback, store: sessions

      confirm "Would you like to receive updates about the next game?",
        denied: "Understood. Farewell, and well played." do
        ask :email, prompt: "Your email address", validate: :email
        persist :email, store: sessions
        say "Perfect. We'll be in touch.", style: :success
      end
    end
  end
end

BBS.start
