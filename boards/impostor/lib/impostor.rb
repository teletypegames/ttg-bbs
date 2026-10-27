# frozen_string_literal: true

require 'bbs'
require_relative 'impostor/code_generator'

# The debrief terminal of Definitely not an Impostor as a rubbs flow. It runs
# the standalone Impostor BBS (bbs.rb), and another rubbs BBS mounts it as a
# door: `door :impostor, Impostor.flow(sessions: store), label: '&Impostor'`.
# `c64: true` gives the same terminal for a PETSCII line: its screens are
# drawn for 40 columns.
module Impostor
  SCREENS = File.expand_path('../screens', __dir__)

  SESSION_HEADERS = %w[session_id timestamp player_name code feedback email].freeze

  def self.sessions_store(path) = BBS::Store.new(path: path, headers: SESSION_HEADERS)

  def self.flow(sessions:, c64: false)
    suffix = c64 ? '_c64' : ''
    BBS::Flow.define(screens_dir: SCREENS) do
      screen :"welcome#{suffix}"

      banner "IDENTITY VERIFICATION", style: :info

      ask :player_name, prompt: "Player Name", transform: :upcase
      ask :code,        prompt: "Code"
      persist :player_name, :code, store: sessions

      pause "Verifying identity...", seconds: 1.2

      gate denied: "Access denied. Code mismatch." do |ctx|
        CodeGenerator.decrypt(ctx[:code]) == ctx[:player_name][0, CodeGenerator::NAME_LEN]
      end

      confirm "Norman, is that you?", denied: "Very well. Goodbye." do
        screen :"congrats#{suffix}"

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
end
