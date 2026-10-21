# frozen_string_literal: true

require 'bbs'

# The model the BBS's own characters (Ra, the TTG Master) talk through: the
# shared model service (infra/llm). BBS_LLM_* names it; where one is unset or
# empty, the characters use SERMO's setting, the same service and key.
module Characters
  def self.env(name)
    own = ENV["BBS_LLM_#{name}"].to_s
    own.empty? ? ENV.fetch("SERMO_LLM_#{name}", nil) : own
  end

  def self.client
    BBS::AI::Client.new(url: env('URL').to_s, model: env('MODEL'), api_key: env('API_KEY'))
  end
end
