# frozen_string_literal: true

require 'time'

# An editor of the blog, a row of the users table: one who may log in and
# write, with the digest of their password (EditorService). A name is the
# same whatever its case (COLLATE NOCASE). Removing an editor keeps their
# posts, without an author (ON DELETE SET NULL).
class UserModel < BBS::Model
  table :users

  # The editors by name, without their digests.
  def self.by_name = select(:id, :name).order(:name).all

  def self.exists?(name) = !where(name: name).empty?

  # The UserModel of +name+ (case does not matter) and its digest, or nil.
  def self.credentials(name)
    user = where(name: name).first
    user && [user, user.password_digest]
  end

  # The id of the new editor.
  def self.add(name, digest) = insert(name: name, password_digest: digest, created_at: Time.now.utc.iso8601)

  # The number of editors changed: 0 when there was no such editor.
  def self.set_digest(name, digest) = where(name: name).update(password_digest: digest)

  # The number of editors removed: 0 when there was no such editor.
  def self.remove(name) = where(name: name).delete
end
