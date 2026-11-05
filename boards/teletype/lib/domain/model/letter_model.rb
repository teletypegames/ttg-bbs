# frozen_string_literal: true

require 'time'
require 'securerandom'

# A letter of the board's mail: between registered names, or a caller's
# feedback to the sysop (addressed to "Sysop").
class LetterModel < Rubbs::Common::Storage::Model
  table :mail
  unrestrict_primary_key

  def self.append(from, to, subject, body)
    create(
      id:            SecureRandom.hex(6),
      timestamp:     Time.now.iso8601,
      sender:        from,
      recipient:     to,
      recipient_key: Rubbs::Common::Auth::Names.key(to),
      subject:       subject,
      body:          body,
      read:          0
    )
  end

  # Letters to any of the names, newest first.
  def self.to(names)
    where(recipient_key: names.map { |name| Rubbs::Common::Auth::Names.key(name) }).order(Sequel.desc(Sequel.lit('rowid'))).all
  end

  def self.mark_read(id) = where(id: id).update(read: 1)

  def self.remove(id) = where(id: id).delete

  def from = sender
  def to   = recipient
  def read? = read == 1
  def time = Time.parse(timestamp)
end
