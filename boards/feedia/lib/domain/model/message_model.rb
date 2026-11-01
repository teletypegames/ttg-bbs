# frozen_string_literal: true

require 'json'
require 'bbs/text'

# A message a caller sent the admins: kind ('suggestion' or 'feedback'),
# time (ISO 8601), the caller's name, and the suggested feed's name and url
# or the text. The fields a kind does not use are nil.
MessageModel = Data.define(:kind, :at, :from, :name, :url, :text) do
  # A message from a Hash with some of the fields (Symbol keys); the others
  # are nil, unknown keys are dropped.
  def self.from_h(hash)
    fields = members.to_h { |m| [m, nil] }.merge(hash.slice(*members))
    new(**fields)
  end

  # A message from a line of the old inbox.jsonl, its text cleaned; nil
  # when the line is not one.
  def self.from_json(line)
    hash = JSON.parse(line)
    return unless hash.is_a?(Hash) && %w[suggestion feedback].include?(hash['kind']) && hash['at'].is_a?(String)

    from_h(hash.transform_keys(&:to_sym).transform_values { |v| v.nil? ? nil : BBS::Text.clean(v) })
  rescue JSON::ParserError
    nil
  end
end
