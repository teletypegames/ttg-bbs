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
  KDF_GATE   = Mutex.new

  def initialize(path)
    @path = path
    @mu   = Mutex.new
    fresh!
  end

  def exists?(name)
    @mu.synchronize { fresh!.key?(key_for(name)) }
  end

  def verify(name, password)
    account = @mu.synchronize { fresh![key_for(name)] }
    return false unless account

    digest = hash(password, [account.salt].pack('H*'))
    OpenSSL.fixed_length_secure_compare(digest, account.digest)
  end

  def save(name, password)
    salt    = SecureRandom.random_bytes(16)
    account = Account.new(key_for(name), name, salt.unpack1('H*'), hash(password, salt), Time.now.iso8601)
    @mu.synchronize do
      fresh![account.key] = account
      write_all
      @mtime = mtime
    end
    account
  end

  private

  def key_for(name) = name.to_s.strip.downcase

  # bin/account writes the file from another process: the accounts are read
  # again whenever the file changed, so a write here never drops its rows.
  def fresh!
    current = mtime
    if @by_key.nil? || current != @mtime
      @by_key = load
      @mtime  = current
    end
    @by_key
  end

  def mtime = File.exist?(@path) ? File.mtime(@path) : nil

  # PBKDF2 holds the interpreter lock: one at a time, so a flood of password
  # guesses cannot stall every other caller's screen.
  def hash(password, salt)
    KDF_GATE.synchronize do
      OpenSSL::KDF.pbkdf2_hmac(password.to_s, salt: salt, iterations: ITERATIONS,
                                               length: 32, hash: 'sha256').unpack1('H*')
    end
  end

  def load
    return {} unless File.exist?(@path)

    CSV.read(@path, headers: true).to_h { |row| [row['key'], Account.new(*HEADER.map { |h| row[h] })] }
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
