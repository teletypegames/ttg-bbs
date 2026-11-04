# frozen_string_literal: true

require 'openssl'
require 'securerandom'

# A password as the board keeps it: a random salt and a PBKDF2-SHA256
# digest, both hex. One digest at a time (GATE): PBKDF2 holds the
# interpreter lock, so a flood of guesses cannot stall every other
# caller's screen.
module Password
  ITERATIONS = 100_000
  GATE       = Mutex.new

  module_function

  def salt = SecureRandom.random_bytes(16).unpack1('H*')

  def digest(password, salt)
    GATE.synchronize do
      OpenSSL::KDF.pbkdf2_hmac(
        password.to_s,
        salt:       [salt].pack('H*'),
        iterations: ITERATIONS,
        length:     32,
        hash:       'sha256'
      ).unpack1('H*')
    end
  end

  def match?(password, salt, digest)
    OpenSSL.fixed_length_secure_compare(digest(password, salt), digest.to_s)
  rescue ArgumentError
    false
  end
end
