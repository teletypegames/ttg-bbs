# frozen_string_literal: true

require 'time'

# A message a caller sent the admins before the network's feedback (ttg-common
# TTG::Feedback), a row of the messages table: kind ('suggestion' or
# 'feedback'), time (ISO 8601), the caller's name (+sender+), the suggested
# feed's name and url or the text, and when it was handed over to the
# network (+exported_at+).
class MessageModel < Rubbs::Common::Storage::Model
  table :messages

  # The oldest +limit+ messages not handed over yet.
  def self.unexported(limit) = where(exported_at: nil).order(:id).limit(limit).all

  # Marks +messages+ handed over now.
  def self.exported(messages) = where(id: messages.map(&:id)).update(exported_at: Time.now.utc.iso8601)

  # The message as a row of TTG::Feedback's import: a suggestion as the
  # +feed+ kind with its address, read already.
  def to_feedback
    suggestion = kind == 'suggestion'
    {
      kind:       suggestion ? 'feed' : 'feedback',
      name:       sender,
      subject:    name.to_s,
      link:       url,
      created_at: at,
      body:       text.to_s.empty? ? [name, url].compact.join(' ') : text,
      state:      'read'
    }
  end
end
