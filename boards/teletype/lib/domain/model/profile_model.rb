# frozen_string_literal: true

require 'time'

# The profile of a registered name: signature, location, homepage, notes
# and art.
class ProfileModel < Rubbs::Common::Storage::Model
  table :profiles

  FIELDS = %i[signature location homepage notes art].freeze

  # The profile of +username+ in any case, or nil.
  def self.of(username) = self[Rubbs::Common::Auth::Names.key(username)]

  # Makes or updates the profile of +username+: the FIELDS given (nil ones
  # left as they are), the name's spelling and the time.
  def self.upsert(username:, **fields)
    key    = Rubbs::Common::Auth::Names.key(username)
    values = fields.slice(*FIELDS).compact
    db.transaction do
      dataset.insert_conflict(target: :user_key, update: {
        username:   Sequel[:excluded][:username],
        updated_at: Sequel[:excluded][:updated_at]
      })
        .insert(user_key: key, username: username, updated_at: Time.now.utc.iso8601)
      where(user_key: key).update(values) unless values.empty?
    end
  end
end
