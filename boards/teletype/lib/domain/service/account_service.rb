# frozen_string_literal: true

# Who may use which name. Anonymous and malformed names never register;
# sysop names are created only from the server shell (bin/account), so a
# caller cannot claim one first over telnet.
class AccountService
  NAME_PATTERN    = /\A[\p{L}\p{N}][\p{L}\p{N} ._-]{0,19}\z/
  MIN_PASSWORD    = 6
  ANONYMOUS       = 'Anonymous'

  def initialize(repo, reserved: [])
    @repo     = repo
    @reserved = reserved.map(&:downcase)
  end

  def self.normalize_name(raw)
    name = raw.to_s.dup.force_encoding(Encoding::UTF_8).scrub('').strip.gsub(/\s+/, ' ')
    name.match?(NAME_PATTERN) ? name : ANONYMOUS
  end

  def registered?(name)            = @repo.exists?(name)
  def authenticate(name, password) = @repo.verify(name, password)

  def register(name, password, confirm)
    return :anonymous  if name.to_s.casecmp?(ANONYMOUS)
    return :reserved   if @reserved.include?(name.to_s.downcase)
    return :taken      if registered?(name)
    return :too_short  if password.to_s.length < MIN_PASSWORD
    return :mismatch   unless password == confirm

    @repo.save(name, password)
    :ok
  end

  # Server-side: create or reset any account, sysops included.
  def set_password(name, password)
    return :too_short if password.to_s.length < MIN_PASSWORD

    @repo.save(name, password)
    :ok
  end
end
