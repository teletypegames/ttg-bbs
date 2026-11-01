# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

# The lead of an English Wikipedia article as plain text, through the Action
# API's extracts (the way Alexandria BBS reads Wikipedia). The answers are
# kept in a bounded LRU cache, and every caller shares one pace towards
# Wikipedia: at most RATE requests a second, and a request that would wait
# longer than MAX_WAIT is not sent. Wikipedia asks every client to name
# itself in the User-Agent.
class WikipediaRepository
  API          = 'https://en.wikipedia.org/w/api.php'
  USER_AGENT   = 'CommodexBBS/0.1 (Teletype Games telnet BBS; https://teletypegames.org; ' \
                 'https://git.teletypegames.org/bbs/commodex)'
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 15
  RATE         = 5
  MAX_WAIT     = 3
  TTL          = 86_400
  # A lead longer than this many characters is cut at a paragraph.
  MAX_TEXT     = 6000

  def initialize(cache_size: 200)
    @cache_size = cache_size
    @cache      = {}
    @lock       = Mutex.new
    @next_slot  = 0.0
  end

  # The SummaryModel of the article +title+ (redirects followed); :missing
  # when there is no such article, nil when Wikipedia did not answer.
  def summary(title)
    hit = cached(title)
    return hit unless hit.nil?

    value = fetch(title)
    store(title, value) unless value.nil?
    value
  end

  private

  def fetch(title)
    data = api(action: 'query', prop: 'extracts|info', exintro: 1, explaintext: 1, redirects: 1, inprop: 'url',
               titles: title)
    return nil unless data

    page = data.dig('query', 'pages', 0)
    text = page && page['extract'].to_s.strip
    return :missing if page.nil? || page['missing'] || page['invalid'] || text.empty?

    SummaryModel.new(title: page['title'], url: page['fullurl'], paragraphs: paragraphs(text).freeze)
  end

  def paragraphs(text)
    out = []
    text.split(/\n+/).map { |p| p.gsub(/\s+/, ' ').strip }.reject(&:empty?).each do |p|
      break if out.any? && out.sum(&:size) + p.size > MAX_TEXT

      out << p.freeze
    end
    out
  end

  def api(**params)
    my_turn? or return nil
    uri = URI(API)
    uri.query = URI.encode_www_form(params.merge(format: 'json', formatversion: 2))
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.get(uri.request_uri, 'User-Agent' => USER_AGENT, 'Accept-Encoding' => 'identity')
    end
    return JSON.parse(res.body) if res.is_a?(Net::HTTPSuccess)

    warn "commodex: Wikipedia answered #{res.code}"
    nil
  rescue StandardError => e
    warn "commodex: Wikipedia: #{e.class}: #{e.message}"
    nil
  end

  # Waits for this request's turn; false when the queue is too long.
  def my_turn?
    wait = @lock.synchronize do
      now  = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      slot = [@next_slot, now].max
      next nil if slot - now > MAX_WAIT

      @next_slot = slot + (1.0 / RATE)
      slot - now
    end
    return false if wait.nil?

    sleep wait if wait.positive?
    true
  end

  def cached(title)
    @lock.synchronize do
      entry = @cache.delete(title)
      next nil unless entry && now - entry[0] < TTL

      @cache[title] = entry
      entry[1]
    end
  end

  def store(title, value)
    @lock.synchronize do
      @cache.delete(title)
      @cache[title] = [now, value]
      @cache.shift while @cache.size > @cache_size
    end
  end

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
