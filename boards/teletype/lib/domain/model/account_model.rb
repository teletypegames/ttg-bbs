# frozen_string_literal: true

require 'time'

# A registered caller, one row a name with its salted PBKDF2 digest
# (Password). Names are matched by their key, any case; the spelling the
# name registered with is kept for display.
class AccountModel < BBS::Model
  table :accounts
  unrestrict_primary_key

  # The account of +name+ in any case, or nil.
  def self.named(name) = self[Names.key(name)]

  # The spellings of every registered name, in sign-up order.
  def self.names = order(Sequel.lit('rowid')).select_map(:name)

  # The registered name +name+ is a look-alike of (another key, the same
  # Names.skeleton), or nil.
  def self.look_alike(name)
    where(skeleton: Names.skeleton(name)).exclude(name_key: Names.key(name)).order(Sequel.lit('rowid')).get(:name)
  end

  # Adds the account unless its name or a look-alike of it is taken by
  # then: :ok, :taken or :look_alike, decided in one transaction.
  def self.register(name, salt, digest)
    db.transaction(mode: :immediate) do
      next :taken if named(name)
      next :look_alike if look_alike(name)

      create(**row(name, salt, digest))
      :ok
    end
  end

  # Sets the password of +name+, creating the account when there is none
  # (bin/account, sysops included).
  def self.set_password(name, salt, digest)
    dataset.insert_conflict(target: :name_key, update: { salt: Sequel[:excluded][:salt], digest: Sequel[:excluded][:digest] })
           .insert(row(name, salt, digest))
  end

  def self.row(name, salt, digest)
    { name_key: Names.key(name), name: name, skeleton: Names.skeleton(name), salt: salt, digest: digest,
      created_at: Time.now.iso8601 }
  end
  private_class_method :row
end
