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

    banner "IDENTITY VERIFICATION", style: :info

    ask :player_name, prompt: "Player Name", transform: :upcase
    ask :code,        prompt: "Code"
    persist :player_name, :code, store: sessions

    pause "Verifying identity...", seconds: 1.2

    gate denied: "Access denied. Code mismatch." do |ctx|
      BBS::CodeGenerator.decrypt(ctx[:code]) == ctx[:player_name][0, BBS::CodeGenerator::NAME_LEN]
    end

    confirm "Norman, is that you?", denied: "Very well. Goodbye." do
      screen :congrats

      menu ">", loop: true do
        option "Leave feedback" do
          ask :feedback, prompt: "Feedback"
          persist :feedback, store: sessions
          say "Feedback recorded. Thank you.", style: :success
        end

        option "Subscribe to updates" do
          ask :email, prompt: "Email address", validate: :email
          persist :email, store: sessions
          say "Perfect. We'll be in touch.", style: :success
        end

        option "Exit" do
          exit_menu
        end
      end
    end
  end
end

BBS.start
