# frozen_string_literal: true

require 'time'

# A member of the board: a caller with an account of the network
# (Rubbs::Common::Auth), one row a name, remembered when they first come in signed
# in. The spelling of the account is kept for display, its id beside it;
# the board's own accounts of before came in with the table.
class MemberModel < Rubbs::Common::Storage::Model
  table :members
  unrestrict_primary_key

  # The member +name+ in any case, or nil.
  def self.named(name) = self[Rubbs::Common::Auth::Names.key(name)]

  # The names of every member, in the order they joined.
  def self.names = order(Sequel.lit('rowid')).select_map(:name)

  # Remembers the signed-in +identity+ (a Rubbs::Common::Auth::Identity): a new
  # member, or the spelling and account of one already here.
  def self.remember(identity)
    update = { name: Sequel[:excluded][:name], account_id: Sequel[:excluded][:account_id] }
    dataset.insert_conflict(target: :name_key, update: update).insert(
      name_key:   Rubbs::Common::Auth::Names.key(identity.name),
      name:       identity.name,
      account_id: identity.id.to_s,
      created_at: Time.now.iso8601
    )
  end
end
