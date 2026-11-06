# frozen_string_literal: true

require 'erb'
require 'json'

# The public API of 16colo.rs (api.16colo.rs/v1) and the raw files of its
# packs (16colo.rs/pack/NAME/raw/FILE), read on demand through Rubbs::Common::Web::HTTP.
# The listings are kept in a Rubbs::Common::Storage::Cache for +ttl+ seconds; a dead API gives
# the last listing it sent, or raises Rubbs::Common::Web::HTTP::Error (Unavailable for an
# error status or an answer that is no listing). The raw files pass a small
# cache too, so callers opening one piece at once fetch it once; a file
# over +max_bytes+ raises Rubbs::Common::Web::HTTP::TooLarge. Nothing is fetched ahead: a
# year's pack list when it is opened, a pack's file list when it is opened,
# a file when it is shown.
class SixteenColorsRepository
  # A listing or a file the archive did not give.
  class Unavailable < Rubbs::Common::Web::HTTP::Error; end

  PAGE_SIZE      = 200
  MAX_PAGES      = 10
  MAX_LISTINGS   = 64
  MAX_JSON_BYTES = 4 * 1024 * 1024
  RAW_TTL        = 600
  MAX_RAWS       = 16

  attr_reader :site_url

  def initialize(api_url:, site_url:, ttl:, max_bytes:)
    @api_url    = api_url.delete_suffix('/')
    @site_url   = site_url.delete_suffix('/')
    @max_bytes  = max_bytes
    @listings   = Rubbs::Common::Storage::Cache.new(ttl: ttl, max_entries: MAX_LISTINGS)
    @raws       = Rubbs::Common::Storage::Cache.new(ttl: RAW_TTL, max_entries: MAX_RAWS, max_bytes: MAX_RAWS * max_bytes)
  end

  # The years of the archive that have packs, newest first.
  def years
    @listings.fetch(:years) do
      json = get_json("#{@api_url}/v1/year")
      raise Unavailable, 'no year list' unless json.is_a?(Hash)

      json.filter_map { |year, counts| YearModel.new(year.to_i, counts['packs'].to_i) if counts.is_a?(Hash) }
        .select { |y| y.packs.positive? }.sort_by { |y| -y.year }
    end
  end

  # The packs of +year+, by name; the pages read so far when a later page
  # fails.
  def packs(year)
    year = Integer(year)
    @listings.fetch([:packs, year]) do
      packs, pages = packs_page(year, 1)
      (2..[pages, MAX_PAGES].min).each { |page| packs.concat(packs_page(year, page).first) }
      packs
    rescue Rubbs::Common::Web::HTTP::Error
      raise if packs.nil? || packs.empty?

      packs
    end
  end

  # The files of the pack +name+, as the archive lists them.
  def files(name)
    @listings.fetch([:files, name]) do
      json = get_json("#{@api_url}/v1/pack/#{escape(name)}?sauce=true")
      result = json.is_a?(Hash) && json['results'].is_a?(Array) ? json['results'].first : nil
      raise Unavailable, 'no file list' unless result.is_a?(Hash) && result['files'].is_a?(Hash)

      result['files'].filter_map { |file, h| ArtFileModel.from_api(file, h, name) }
    end
  end

  # The bytes of +file+ in the pack +pack+. Raises Rubbs::Common::Web::HTTP::TooLarge when
  # it is larger than +max_bytes+.
  def raw(pack, file) = @raws.fetch([pack, file]) { get("#{pack_url(pack)}/raw/#{escape(file)}", @max_bytes).freeze }

  def pack_url(pack) = "#{@site_url}/pack/#{escape(pack)}"

  def file_url(pack, file) = "#{pack_url(pack)}/#{escape(file)}"

  private

  def escape(part) = ERB::Util.url_encode(part.to_s)

  # The packs of one page of +year+'s list, and the number of pages.
  def packs_page(year, page)
    json = get_json("#{@api_url}/v1/year/#{year}?pagesize=#{PAGE_SIZE}&page=#{page}")
    raise Unavailable, "no page #{page} of #{year}" unless json.is_a?(Hash) && json['results'].is_a?(Array)

    [json['results'].filter_map { |h| PackModel.from_api(h) }, json.dig('page', 'pages').to_i]
  end

  def get_json(url)
    JSON.parse(utf8(get(url, MAX_JSON_BYTES)))
  rescue JSON::ParserError => e
    raise Unavailable, "#{url.split('?').first} answered no JSON: #{e.message[0, 80]}"
  end

  def get(url, max_bytes)
    response = Rubbs::Common::Web::HTTP.get(url, headers: { 'Accept-Encoding' => 'identity' }, max_bytes: max_bytes)
    raise Unavailable, "#{url.split('?').first} answered #{response.status}" unless response.ok?

    response.body
  end

  def utf8(bytes) = bytes.force_encoding(Encoding::UTF_8)
end
