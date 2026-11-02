# frozen_string_literal: true

require 'bbs'

# The model the BBS's own characters (Ra, the TTG Master) talk through: the
# shared model service (infra/llm). The composition root (TeletypeBBS.llm)
# names it.
module Characters
  # A client of the model at +url+; an empty +url+ leaves the characters to
  # their canned replies.
  def self.client(url:, model:, api_key:) = BBS::AI::Client.new(url: url.to_s, model: model, api_key: api_key)
end
