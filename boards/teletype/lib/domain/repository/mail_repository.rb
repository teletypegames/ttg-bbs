# frozen_string_literal: true

require 'time'
require 'securerandom'

# Private mail between registered names, and the callers' feedback to the
# sysop (addressed to "Sysop").
class MailRepository
  Letter = Struct.new(:id, :timestamp, :from, :to, :subject, :body, :read) do
    def read? = read == 1
    def time  = Time.parse(timestamp)
  end

  def initialize(db) = @db = db

  def append(from, to, subject, body)
    letter = Letter.new(SecureRandom.hex(6), Time.now.iso8601, from, to, subject, body, 0)
    @db.insert('INSERT INTO mail (id, timestamp, sender, recipient, recipient_key, subject, body, read) ' \
               'VALUES (?, ?, ?, ?, ?, ?, ?, ?)', *letter.to_a[0, 4], Names.key(to), *letter.to_a[4, 3])
    letter
  end

  # Letters to any of the names, newest first.
  def to(names)
    keys = names.map { |name| Names.key(name) }
    @db.query("SELECT * FROM mail WHERE recipient_key IN (#{(['?'] * keys.size).join(', ')}) ORDER BY rowid DESC", *keys)
       .map { |row| letter(row) }
  end

  def mark_read(id) = @db.change('UPDATE mail SET read = 1 WHERE id = ?', id)

  def delete(id) = @db.change('DELETE FROM mail WHERE id = ?', id)

  private

  def letter(row)
    Letter.new(row['id'], row['timestamp'], row['sender'], row['recipient'], row['subject'], row['body'], row['read'])
  end
end
