# frozen_string_literal: true

module BBS
  DEBRIEF = Flow.define do
    screen :welcome

    ask :player_name, prompt: "Player Name", transform: :upcase
    ask :code,        prompt: "Code"
    persist :player_name, :code

    pause "Verifying identity...", seconds: 1.2

    gate denied: "Access denied. Code mismatch." do |ctx|
      CodeGenerator.decrypt(ctx[:code]) == ctx[:player_name][0, CodeGenerator::NAME_LEN]
    end

    confirm "Norman, is that you?", denied: "Very well. Goodbye." do
      screen :congrats

      ask :feedback, prompt: "Any feedback about the game?"
      persist :feedback

      confirm "Would you like to receive updates about the next game?",
        denied: "Understood. Farewell, and well played." do
        ask :email, prompt: "Your email address", validate: :email
        persist :email
        say "Perfect. We'll be in touch.", style: :success
      end
    end
  end
end
