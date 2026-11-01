# frozen_string_literal: true

require 'json'
require 'uri'

# Wikipedia's Action API as one board asks it: a GET through BBS::HTTP that
# names the board in its User-Agent (Wikipedia may answer 403 without one),
# paced so that all callers together send at most RATE requests a second. A
# request that would wait longer than MAX_WAIT for its turn is not sent, so
# a crowd on the board cannot get our address throttled there. The same
# file serves Alexandria BBS and Commodex BBS.
class WikipediaClient
  RATE     = 5
  MAX_WAIT = 3 # seconds

  # Wikipedia did not answer, or not in time: the message is for the log.
  class Error < StandardError; end

  def initialize(user_agent:, pace: BBS::RateLimit.new(limit: RATE, per: 1))
    @user_agent = user_agent
    @pace       = pace
  end

  # The JSON text of the Action API's answer to +params+ on the +lang+
  # Wikipedia (formatversion 2), as UTF-8. Raises Error.
  def get(lang, **params)
    raise Error, 'busy: too many Wikipedia requests at once' unless turn?
    response = BBS::HTTP.get(url(lang, params), user_agent: @user_agent, headers: { 'Accept-Encoding' => 'identity' })
    raise Error, "Wikipedia answered #{response.status}" unless response.ok?
    BBS::Text.utf8(response.body)
  rescue BBS::HTTP::Error => e
    raise Error, e.message
  end

  private

  def url(lang, params)
    query = URI.encode_www_form(params.merge(format: 'json', formatversion: 2))
    "https://#{lang}.wikipedia.org/w/api.php?#{query}"
  end

  # Waits for a turn; false when none comes within MAX_WAIT.
  def turn?
    deadline = monotonic + MAX_WAIT
    until @pace.allow?(:wikipedia)
      wait = @pace.wait(:wikipedia)
      return false if monotonic + wait > deadline
      sleep wait
    end
    true
  end

  def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
