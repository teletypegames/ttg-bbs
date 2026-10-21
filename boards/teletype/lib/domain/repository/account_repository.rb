# frozen_string_literal: true

require 'csv'
require 'time'
require 'openssl'
require 'securerandom'
require 'fileutils'

# Registered callers: one CSV row per name with a salted PBKDF2-SHA256 hash.
# Names are matched case-insensitively; the display spelling is kept.
class AccountRepository
  Account = Struct.new(:key, :name, :salt, :digest, :created_at)

  ITERATIONS = 100_000
  HEADER     = %w[key name salt digest created_at].freeze

  def initialize(path)
    @path = path
    @mu   = Mutex.new
    @by_key = load
  end

  def exists?(name)
    @mu.synchronize { @by_key.key?(key_for(name)) }
  end

  def verify(name, password)
    account = @mu.synchronize { @by_key[key_for(name)] }
    return false unless account

    digest = hash(password, [account.salt].pack('H*'))
    OpenSSL.fixed_length_secure_compare(digest, account.digest)
  end

  def save(name, password)
    salt    = SecureRandom.random_bytes(16)
    account = Account.new(key_for(name), name, salt.unpack1('H*'), hash(password, salt), Time.now.iso8601)
    @mu.synchronize do
      @by_key[account.key] = account
      write_all
    end
    account
  end

  private

  def key_for(name) = name.to_s.strip.downcase

  def hash(password, salt)
    OpenSSL::KDF.pbkdf2_hmac(password.to_s, salt: salt, iterations: ITERATIONS,
                                             length: 32, hash: 'sha256').unpack1('H*')
  end

  def load
    return {} unless File.exist?(@path)

    CSV.read(@path, headers: true).to_h { |row| [row['key'], Account.new(*HEADER.map { |h| row[h] })] }
  rescue StandardError
    {}
  end

  def write_all
    FileUtils.mkdir_p(File.dirname(@path))
    tmp = "#{@path}.tmp"
    CSV.open(tmp, 'w') do |csv|
      csv << HEADER
      @by_key.each_value { |a| csv << a.to_a }
    end
    File.chmod(0o600, tmp)
    File.rename(tmp, @path)
  end
end
