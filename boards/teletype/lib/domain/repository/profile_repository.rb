# frozen_string_literal: true

require 'time'

# The profile of a registered name: signature, location, homepage, notes.
class ProfileRepository
  FIELDS = %w[signature location homepage notes art].freeze

  def initialize(db) = @db = db

  def upsert(username:, **fields)
    values = FIELDS.to_h { |name| [name, fields[name.to_sym]] }.compact
    @db.transaction do
      @db.query('INSERT INTO profiles (user_key, username, updated_at) VALUES (?, ?, ?) ON CONFLICT (user_key) ' \
                'DO UPDATE SET username = excluded.username, updated_at = excluded.updated_at',
                Names.key(username), username, Time.now.utc.iso8601)
      values.each do |name, value|
        @db.query("UPDATE profiles SET #{name} = ? WHERE user_key = ?", value, Names.key(username))
      end
    end
  end

  # {"username" => ..., "signature" => ..., ...} or nil.
  def find(username) = @db.get('SELECT * FROM profiles WHERE user_key = ?', Names.key(username))
end
