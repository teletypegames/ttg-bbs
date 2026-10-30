# frozen_string_literal: true

require 'openssl'
require 'securerandom'

# The editors: their names, their passwords and logging in. A password is
# kept as a PBKDF2-SHA256 digest with a random salt.
class EditorService
  MAX_NAME   = 24
  MIN_PASS   = 8
  ITERATIONS = 200_000

  def initialize(repo)
    @repo = repo
  end

  def all = @repo.all

  # The UserModel whose name and password these are, or nil. A name nobody
  # has still costs a key derivation, so the time taken does not tell it
  # apart.
  def authenticate(name, password)
    user, digest = @repo.credentials(name.to_s.strip)
    return nil unless EditorService.password?(digest || EditorService.digest(''), password.to_s) && user

    user
  end

  # :ok, or a Symbol naming what is wrong.
  def add(name, password)
    name = name.to_s.strip
    return :bad_name unless name.match?(/\A[A-Za-z0-9_.-]{2,#{MAX_NAME}}\z/o)
    return :short_password if password.to_s.length < MIN_PASS
    return :taken if @repo.exists?(name)

    @repo.insert(name, EditorService.digest(password))
    :ok
  end

  def set_password(name, password)
    return :short_password if password.to_s.length < MIN_PASS

    @repo.set_digest(name.to_s.strip, EditorService.digest(password)).positive? ? :ok : :no_user
  end

  # The posts of a removed editor stay, without an author.
  def remove(name) = @repo.delete(name.to_s.strip).positive? ? :ok : :no_user

  # PBKDF2-SHA256 with a random salt, as "pbkdf2-sha256$iterations$salt$hash".
  def self.digest(password, salt: SecureRandom.bytes(16), iterations: ITERATIONS)
    hash = OpenSSL::KDF.pbkdf2_hmac(password.to_s, salt: salt, iterations: iterations, length: 32, hash: 'sha256')
    ['pbkdf2-sha256', iterations, [salt].pack('m0'), [hash].pack('m0')].join('$')
  end

  def self.password?(digest, password)
    kind, iterations, salt, hash = digest.to_s.split('$')
    return false unless kind == 'pbkdf2-sha256' && hash

    fresh = digest(password, salt: salt.unpack1('m0'), iterations: iterations.to_i)
    OpenSSL.fixed_length_secure_compare(fresh, digest)
  rescue ArgumentError
    false
  end
end
