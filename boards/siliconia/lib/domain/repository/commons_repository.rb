# frozen_string_literal: true

# Wikimedia Commons as the board asks it: a file's licence, author and small thumbnail address
# (the Action API's imageinfo with extmetadata, through rubbs' Rubbs::Common::Web::MediaWiki, RATE
# requests a second for all callers), and the thumbnail's bytes. Failures go up as
# Rubbs::Common::Web::HTTP::Error.
class CommonsRepository
  ENDPOINT  = 'https://commons.wikimedia.org/w/api.php'
  RATE      = 5
  # The width of the thumbnail asked for, in pixels.
  THUMB     = 250
  # The largest thumbnail read.
  MAX_BYTES = 512 * 1024

  # What Commons says of a file: its thumbnail address, its licence's short name and address,
  # the author (plain text), and the file's page.
  Info = Data.define(:thumb, :license, :license_url, :artist, :page)

  def initialize(
    api: Rubbs::Common::Web::MediaWiki.new(
      endpoint:   ENDPOINT,
      user_agent: WikidataRepository::USER_AGENT,
      name:       'Commons',
      rate:       RATE
    )
  )
    @api = api
  end

  # The Info of the Commons file +name+; nil when Commons has no such file.
  def info(name)
    data = @api.get(
      action:              'query',
      titles:              "File:#{name}",
      prop:                'imageinfo',
      iiprop:              'url|extmetadata',
      iiurlwidth:          THUMB,
      iiextmetadatafilter: 'LicenseShortName|LicenseUrl|Artist'
    )
    page = data.dig('query', 'pages', 0)
    image = page&.dig('imageinfo', 0)
    image && info_of(image)
  end

  # The bytes of the thumbnail at +url+.
  def thumbnail(url)
    response = Rubbs::Common::Web::HTTP.get(url, user_agent: WikidataRepository::USER_AGENT, max_bytes: MAX_BYTES)
    raise Rubbs::Common::Web::HTTP::Error, "Commons answered #{response.status}" unless response.ok?

    response.body
  end

  private

  def info_of(image)
    meta = image['extmetadata'] || {}
    Info.new(
      thumb:       image['thumburl'] || image['url'],
      license:     plain(meta.dig('LicenseShortName', 'value')),
      license_url: plain(meta.dig('LicenseUrl', 'value')),
      artist:      plain(meta.dig('Artist', 'value')),
      page:        plain(image['descriptionurl'])
    )
  end

  # The text of an HTML snippet of Commons: no tags, no entities, one line.
  def plain(html)
    text = html.to_s.gsub(/<[^>]*>/, ' ').gsub('&amp;', '&').gsub('&quot;', '"').gsub('&#039;', "'").gsub(/&[a-z]+;/, ' ')
    Rubbs::Common::Text.line(text)
  end
end
