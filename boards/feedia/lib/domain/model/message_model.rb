# frozen_string_literal: true

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
end
