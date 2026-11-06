# frozen_string_literal: true

require 'time'

# An author of the blog, a row of the users table: the account of the network
# (Rubbs::Common::Auth, its id and name) that wrote a post, kept here so a post knows
# its author's name. An editor is remembered the first time they write. The
# password_digest column is of the blog's own logins before the accounts of
# the network: empty for an author since. Removing an author keeps their
# posts, without an author (ON DELETE SET NULL).
class UserModel < Rubbs::Common::Storage::Model
  table :users

  # Keeps +identity+ (a Rubbs::Common::Auth::Identity) as an author: its id and its
  # name as it is now. Another author row of that name (an editor of the
  # blog's own logins whose account is another) keeps its posts under the
  # name with its number after it.
  def self.remember(identity)
    db.transaction do
      where(name: identity.name).exclude(id: identity.id).each { |other| other.update(name: "#{other.name} ##{other.id}") }
      dataset.insert_conflict(target: :id, update: { name: Sequel[:excluded][:name] })
        .insert(id: identity.id, name: identity.name, password_digest: '', created_at: Time.now.utc.iso8601)
    end
  end
end
