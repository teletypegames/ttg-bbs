# frozen_string_literal: true

require 'rubbs'

module Sermo
  # The ACP's conversational core — SERMO's second (analog-cognitive)
  # architecture.
  #
  # At the `> ` prompt, anything that is NOT a literal, built-in command lands
  # here: the FakeOS `on_unknown` hook routes the natural-language request over
  # the ADI-76 bus to the Lapis-ACP.
  #
  # Who the ACP is lives in acp.yml, read once at start: the system prompt (the
  # world it knows and the voice from the canon — ExistentialAI + Nokia-punk),
  # the example turns, the sampling settings and the canned replies.
  # SERMO_ACP_PERSONA points at another file, to try a new persona without a
  # release.
  #
  # The thinking is done by a small local model behind an OpenAI-compatible
  # chat endpoint (llama.cpp's llama-server), named by SERMO_LLM_URL, with
  # SERMO_LLM_MODEL when the endpoint serves more than one model and
  # SERMO_LLM_API_KEY when it asks for a key; rubbs' Rubbs::Common::AI does the
  # talking. Without the model, or when it fails, the ACP falls back to the
  # canned replies.
  module Oracle
    PERSONA_PATH = ENV.fetch('SERMO_ACP_PERSONA', File.join(__dir__, 'acp.yml'))
    PERSONA      = Rubbs::Common::AI::Persona.load(PERSONA_PATH)

    CHAT = Rubbs::Common::AI::Chat.new(
      persona: PERSONA,
      client:  Rubbs::Common::AI::Client.new(
        url:     ENV.fetch('SERMO_LLM_URL', ''),
        model:   ENV['SERMO_LLM_MODEL'],
        api_key: ENV['SERMO_LLM_API_KEY']
      ),
      key:     :acp_history,
      history: 2, # only the last exchange: a longer memory makes a model this small copy its own slips
      options: ENV['SERMO_LLM_MAX_TOKENS'] ? { max_tokens: ENV['SERMO_LLM_MAX_TOKENS'].to_i } : {}
    )

    # Returns the reply. With a block, the reply is also yielded piece by
    # piece as it arrives, so the terminal can type it out live.
    def self.answer(question, ctx = {}, &)
      CHAT.reply(question.to_s.dup.force_encoding(Encoding::UTF_8).scrub(''), ctx, &)
    end
  end
end
