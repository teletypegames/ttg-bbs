# frozen_string_literal: true

require 'time'

# Registered callers, one row a name with its salted PBKDF2 digest
# (Password). Names are matched by their key, any case; the spelling the
# name registered with is kept for display.
class AccountRepository
  Account = Struct.new(:name_key, :name, :skeleton, :salt, :digest, :created_at, keyword_init: true)

  def initialize(db) = @db = db

  def exists?(name) = !find(name).nil?

  def find(name)
    row = @db.get('SELECT * FROM accounts WHERE name_key = ?', Names.key(name))
    row && Account.new(**row.transform_keys(&:to_sym))
  end

  # The spellings of every registered name, in sign-up order.
  def names = @db.query('SELECT name FROM accounts ORDER BY rowid').map { |row| row['name'] }

  def created_at(name) = find(name)&.created_at

  # The registered name +name+ is a look-alike of (another key, the same
  # Names.skeleton), or nil.
  def look_alike(name)
    @db.get('SELECT name FROM accounts WHERE skeleton = ? AND name_key != ? ORDER BY rowid',
            Names.skeleton(name), Names.key(name))&.fetch('name')
  end

  # Adds the account unless its name or a look-alike of it is taken by
  # then: :ok, :taken or :look_alike, decided in one transaction.
  def create(name, salt, digest)
    @db.transaction do
      next :taken if exists?(name)
      next :look_alike if look_alike(name)

      @db.insert('INSERT INTO accounts (name_key, name, skeleton, salt, digest, created_at) VALUES (?, ?, ?, ?, ?, ?)',
                 Names.key(name), name, Names.skeleton(name), salt, digest, Time.now.iso8601)
      :ok
    end
  end

  # Sets the password of +name+, creating the account when there is none
  # (bin/account, sysops included).
  def save(name, salt, digest)
    @db.query(<<~SQL, Names.key(name), name, Names.skeleton(name), salt, digest, Time.now.iso8601)
      INSERT INTO accounts (name_key, name, skeleton, salt, digest, created_at) VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT (name_key) DO UPDATE SET salt = excluded.salt, digest = excluded.digest
    SQL
  end
end
