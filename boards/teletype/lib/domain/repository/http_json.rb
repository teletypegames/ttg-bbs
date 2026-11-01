# frozen_string_literal: true

require 'json'
require 'uri'

# The JSON APIs of teletypegames.org and the Gitea server: one GET through
# BBS::HTTP with short timeouts, every string of the answer cleaned of
# control characters before a screen can show it.
module HttpJson
  module_function

  # The parsed answer of +url+ with the query +params+. Raises
  # BBS::HTTP::Error on a failed request or a non-2xx answer.
  def get(url, params = {})
    uri = URI(url)
    uri.query = URI.encode_www_form(params) unless params.empty?
    response = BBS::HTTP.get(uri.to_s, open_timeout: 5, read_timeout: 12, deadline: 20)
    raise BBS::HTTP::Error, "HTTP #{response.status} from #{uri.host}" unless response.ok?

    clean(JSON.parse(BBS::Text.utf8(response.body)))
  end

  # +tree+ (parsed JSON) with every String through BBS::Text.clean.
  def clean(tree)
    case tree
    when String then BBS::Text.clean(tree)
    when Array  then tree.map { |value| clean(value) }
    when Hash   then tree.transform_values { |value| clean(value) }
    else tree
    end
  end

  # A BBS::Cache of remote answers that also remembers a failure for
  # FAILURE_TTL seconds: meanwhile the last good answer stands (or the
  # failure is raised again), so a dead API is not asked on every redraw.
  class Cache
    FAILURE_TTL = 60

    def initialize(ttl:, max_entries: 16)
      @values   = BBS::Cache.new(ttl: ttl, max_entries: max_entries)
      @failures = {}
      @mu       = Mutex.new
    end

    def fetch(key, &) = @values.fetch(key) { attempt(key, &) }

    private

    def attempt(key)
      failed = recent_failure(key)
      raise failed if failed

      yield
    rescue StandardError => e
      @mu.synchronize { @failures[key] = [monotonic, e] } unless e.equal?(failed)
      raise
    end

    def recent_failure(key)
      at, error = @mu.synchronize { @failures[key] }
      error if at && monotonic - at < FAILURE_TTL
    end

    def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
