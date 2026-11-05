# frozen_string_literal: true

require 'json'
require 'rubbs/common/text'

# A message a caller sent the admins, a row of the messages table: kind
# ('suggestion' or 'feedback'), time (ISO 8601), the caller's name
# (+sender+, #from), and the suggested feed's name and url or the text. The
# fields a kind does not use are nil. The inbox keeps the newest KEEP; an
# older one goes when a new one comes.
class MessageModel < Rubbs::Common::Storage::Model
  table :messages

  KEEP = 1000

  # An unsaved message from a Hash with some of the fields kind, at, from,
  # name, url and text (Symbol keys); the others are nil, unknown keys are
  # dropped.
  def self.from_h(hash)
    new(kind: hash[:kind], at: hash[:at], sender: hash[:from], name: hash[:name], url: hash[:url], text: hash[:text])
  end

  # An unsaved message from a line of the old inbox.jsonl, its text
  # cleaned; nil when the line is not one.
  def self.from_json(line)
    hash = JSON.parse(line)
    return unless hash.is_a?(Hash) && %w[suggestion feedback].include?(hash['kind']) && hash['at'].is_a?(String)

    from_h(hash.transform_keys(&:to_sym).transform_values { |v| v.nil? ? nil : Rubbs::Common::Text.clean(v) })
  rescue JSON::ParserError
    nil
  end

  # Keeps +messages+ (unsaved MessageModel) in one transaction, then drops
  # all but the newest +keep+. Raises Sequel::DatabaseError when it could
  # not.
  def self.append(*messages, keep: KEEP)
    db.transaction do
      messages.each(&:save)
      prune(keep)
    end
  end

  # The last +limit+ messages, the newest first.
  def self.last(limit) = reverse(:id).limit(limit).all

  # Drops all but the newest +keep+ messages.
  def self.prune(keep) = where(Sequel[:id] <= select(:id).reverse(:id).limit(1, keep)).delete

  # The caller's name.
  def from = sender
end
