# frozen_string_literal: true

require 'openssl'

# The supervisor password that unlocks the private pages for one call. The
# wiki holds the same secret and only serves private page bodies to requests
# carrying it, and the board sends it only for those pages.
#
# Guessing is slow and bounded: every wrong try costs WRONG_DELAY, and after
# FAILURE_LIMIT wrong tries within FAILURE_WINDOW, from any caller, the lock
# refuses everyone until the window has passed.
class SupervisorService
  WRONG_DELAY    = 2   # seconds
  FAILURE_LIMIT  = 10
  FAILURE_WINDOW = 600 # seconds

  def initialize(password, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
    @digest   = digest(password.to_s) unless password.to_s.empty?
    @clock    = clock
    @failures = []
    @mutex    = Mutex.new
  end

  def configured? = !@digest.nil?

  # :unconfigured when the board has no password, :locked after too many
  # wrong tries, otherwise :granted or :wrong.
  def unlock(password)
    return :unconfigured unless configured?
    return :locked if locked?
    return :granted if OpenSSL.fixed_length_secure_compare(digest(password.to_s), @digest)

    fail!
  end

  private

  def digest(text) = OpenSSL::Digest::SHA256.digest(text)

  def locked?
    @mutex.synchronize { recent.size >= FAILURE_LIMIT }
  end

  def fail!
    @mutex.synchronize { @failures = recent << @clock.call }
    warn 'wiki-bbs: wrong supervisor password'
    sleep WRONG_DELAY
    :wrong
  end

  def recent
    now = @clock.call
    @failures.select { |at| now - at < FAILURE_WINDOW }
  end
end
