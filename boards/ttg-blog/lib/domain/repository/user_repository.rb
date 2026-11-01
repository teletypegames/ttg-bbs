# frozen_string_literal: true

require 'time'

# The users table (BlogSchema): the editors and their password digests.
# Removing an editor keeps their posts, without an author.
class UserRepository
  # +db+ is a BBS::SQLite whose schema BlogSchema brought up to date.
  def initialize(db)
    @db = db
  end

  def all = @db.query('SELECT id, name FROM users ORDER BY name').map { |r| UserModel.from_row(r) }

  def exists?(name) = !@db.get('SELECT 1 FROM users WHERE name = ?', name).nil?

  # The UserModel of +name+ (case does not matter) and its digest, or nil.
  def credentials(name)
    row = @db.get('SELECT * FROM users WHERE name = ?', name)
    row && [UserModel.from_row(row), row['password_digest']]
  end

  def insert(name, digest)
    @db.insert('INSERT INTO users (name, password_digest, created_at) VALUES (?, ?, ?)', name, digest,
               Time.now.utc.iso8601)
  end

  # The number of editors changed: 0 when there was no such editor.
  def set_digest(name, digest) = @db.change('UPDATE users SET password_digest = ? WHERE name = ?', digest, name)

  def delete(name) = @db.change('DELETE FROM users WHERE name = ?', name)
end
