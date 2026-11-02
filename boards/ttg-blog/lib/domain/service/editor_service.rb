# frozen_string_literal: true

require 'openssl'
require 'securerandom'

# The editors: their names, their passwords and logging in. A password is
# kept as a PBKDF2-SHA256 digest with a random salt; every derivation goes
# through the LoginGuard, and so does every try at logging in.
class EditorService
  MAX_NAME   = 24
  MIN_PASS   = 8
  ITERATIONS = 200_000

  # The pause after a wrong password, on top of the guard's lock.
  FAIL_DELAY = 1

  def initialize(repo, guard: LoginGuard.new, fail_delay: FAIL_DELAY)
    @repo       = repo
    @guard      = guard
    @fail_delay = fail_delay
  end

  def all = @repo.all

  # The UserModel whose name and password these are, or a Symbol: :locked
  # after too many failed tries of the name or by the caller (a
  # BBS::RateLimit.caller_key), :busy when the derivations are all taken,
  # :wrong for a wrong name or password.
  def login(name, password, caller:)
    name = name.to_s.strip
    return :locked if @guard.locked?(name, caller)

    user = @guard.derive { authenticate(name, password) }
    return user if user
    return :busy if user == :busy

    refuse(name, caller)
  end

  # Seconds until +name+ and +caller+ may try to log in again.
  def locked_for(name, caller) = @guard.wait(name.to_s.strip, caller)

  # :ok, or a Symbol naming what is wrong.
  def add(name, password)
    name = name.to_s.strip
    return :bad_name unless name.match?(/\A[A-Za-z0-9_.-]{2,#{MAX_NAME}}\z/o)
    return :short_password if password.to_s.length < MIN_PASS
    return :taken if @repo.exists?(name)

    @repo.insert(name, EditorService.digest(password))
    :ok
  end

  # The logged-in editor's own change: :ok, :wrong for a wrong +current+
  # password, :short_password, :busy.
  def change_password(name, current, fresh)
    return :short_password if fresh.to_s.length < MIN_PASS

    found = @guard.derive { authenticate(name, current) }
    return :busy if found == :busy
    return :wrong unless found

    set_password(name, fresh)
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

  # The digest a name nobody has is checked against.
  def self.nobody = @nobody ||= digest('')

  def self.password?(digest, password)
    kind, iterations, salt, hash = digest.to_s.split('$')
    return false unless kind == 'pbkdf2-sha256' && hash

    fresh = digest(password, salt: salt.unpack1('m0'), iterations: iterations.to_i)
    OpenSSL.fixed_length_secure_compare(fresh, digest)
  rescue ArgumentError
    false
  end

  private

  # The UserModel, or nil. A name nobody has still costs a key derivation,
  # so the time taken does not tell it apart.
  def authenticate(name, password)
    user, digest = @repo.credentials(name)
    EditorService.password?(digest || EditorService.nobody, password.to_s) && user ? user : nil
  end

  def refuse(name, caller)
    @guard.failed(name, caller)
    BBS.log('login', "failed for #{name.inspect} from #{caller}")
    sleep @fail_delay
    :wrong
  end
end
