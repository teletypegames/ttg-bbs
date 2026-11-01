# frozen_string_literal: true

require 'erb'
require 'json'
require 'net/http'
require 'uri'

# The public API of 16colo.rs (api.16colo.rs/v1) and the raw files of its
# packs (16colo.rs/pack/NAME/raw/FILE), read on demand. The listings are kept
# in memory for +ttl+ seconds (at most MAX_LISTINGS of them); a dead API
# gives the last listing it sent, or nil. Nothing is fetched ahead: a year's
# pack list when it is opened, a pack's file list when it is opened, a file
# when it is shown.
class SixteenColorsRepository
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 20
  PAGE_SIZE    = 200
  MAX_PAGES    = 10
  MAX_LISTINGS = 64

  attr_reader :site_url

  def initialize(api_url:, site_url:, user_agent:, ttl:, max_bytes:)
    @api_url    = api_url.delete_suffix('/')
    @site_url   = site_url.delete_suffix('/')
    @user_agent = user_agent
    @ttl        = ttl
    @max_bytes  = max_bytes
    @listings   = {}
    @lock       = Mutex.new
  end

  # The years of the archive that have packs, newest first; nil when the API
  # never answered.
  def years
    listing(:years) do
      json = get_json("#{@api_url}/v1/year")
      next nil unless json.is_a?(Hash)

      json.filter_map { |year, counts| YearModel.new(year.to_i, counts['packs'].to_i) if counts.is_a?(Hash) }
          .select { |y| y.packs.positive? }.sort_by { |y| -y.year }
    end
  end

  # The packs of +year+, by name; nil when the API never answered.
  def packs(year)
    listing([:packs, year]) do
      packs = []
      page  = 1
      pages = 1
      while page <= pages && page <= MAX_PAGES
        json = get_json("#{@api_url}/v1/year/#{Integer(year)}?pagesize=#{PAGE_SIZE}&page=#{page}")
        break unless json.is_a?(Hash) && json['results'].is_a?(Array)

        pages = json.dig('page', 'pages').to_i
        packs.concat(json['results'].filter_map { |h| PackModel.from_api(h) })
        page += 1
      end
      packs.empty? ? nil : packs
    end
  end

  # The files of the pack +name+, as the archive lists them; nil when the API
  # never answered.
  def files(name)
    listing([:files, name]) do
      json = get_json("#{@api_url}/v1/pack/#{escape(name)}?sauce=true")
      result = json.is_a?(Hash) && json['results'].is_a?(Array) ? json['results'].first : nil
      next nil unless result.is_a?(Hash) && result['files'].is_a?(Hash)

      result['files'].filter_map { |file, h| ArtFileModel.from_api(file, h, name) }
    end
  end

  # The bytes of +file+ in the pack +pack+: nil when the site does not give
  # them, :too_big when it is larger than +max_bytes+.
  def raw(pack, file) = get("#{@site_url}/pack/#{escape(pack)}/raw/#{escape(file)}", limit: @max_bytes)

  def pack_url(pack) = "#{@site_url}/pack/#{escape(pack)}"

  def file_url(pack, file) = "#{pack_url(pack)}/#{escape(file)}"

  private

  def escape(part) = ERB::Util.url_encode(part.to_s)

  def listing(key)
    cached = @lock.synchronize { @listings[key] }
    return cached[:value] if cached && now - cached[:at] < @ttl

    value = yield
    return cached&.dig(:value) if value.nil?

    @lock.synchronize do
      @listings.delete(@listings.min_by { |_, v| v[:at] }.first) if @listings.size >= MAX_LISTINGS && !@listings.key?(key)
      @listings[key] = { value: value.freeze, at: now }
    end
    value
  end

  def get_json(url)
    body = get(url, limit: 8 * 1024 * 1024)
    body.is_a?(String) ? JSON.parse(body) : nil
  rescue JSON::ParserError => e
    warn "pixelia: #{url}: #{e.class}: #{e.message}"
    nil
  end

  def get(url, limit:)
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                        open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      request = Net::HTTP::Get.new(uri.request_uri, 'User-Agent' => @user_agent, 'Accept-Encoding' => 'identity')
      http.request(request) do |res|
        unless res.is_a?(Net::HTTPSuccess)
          warn "pixelia: #{url} answered #{res.code}"
          return nil
        end
        return :too_big if res['Content-Length'].to_i > limit

        body = +''.b
        res.read_body do |chunk|
          body << chunk
          return :too_big if body.bytesize > limit
        end
        return body
      end
    end
  rescue StandardError => e
    warn "pixelia: #{url}: #{e.class}: #{e.message}"
    nil
  end

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
