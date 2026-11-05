# frozen_string_literal: true

require 'fileutils'

# The RFC Editor over HTTP (Rubbs::Common::Web::HTTP: a deadline, a cap on the body,
# redirects to public http(s) addresses only, the board's User-Agent): the
# index, rfc-index.xml, the errata, errata.json, the index and the listing
# of the IENs, and the plain text of an RFC or an IEN as it was published. A
# dead site raises Rubbs::Common::Web::HTTP::Error, a body over the cap its subclass
# Rubbs::Common::Web::HTTP::TooLarge.
class RfcEditorRepository
  # The index is about 14 MB.
  INDEX_MAX = 64 * 1024 * 1024
  INDEX_DEADLINE = 300
  # The longest RFCs are about 1 MB of text.
  TEXT_MAX = 4 * 1024 * 1024
  TEXT_DEADLINE = 60
  READ_TIMEOUT  = 30

  # [site] the base URL of the RFC Editor (https://www.rfc-editor.org)
  def initialize(site:)
    @site = site.delete_suffix('/')
  end

  def index_url = "#{@site}/rfc-index.xml"

  def errata_url = "#{@site}/errata.json"

  # The text of RFC +number+; of IEN -+number+ for a negative one.
  def text_url(number)
    number = Integer(number)
    number.negative? ? "#{@site}/ien/ien#{-number}.txt" : "#{@site}/rfc/rfc#{number}.txt"
  end

  # Saves the index at +path+, streamed into a temporary file next to it,
  # so the download never sits in memory. Raises Rubbs::Common::Web::HTTP::Error or
  # SystemCallError; +path+ is then left as it was.
  def download_index(path) = download(index_url, path)

  # Saves errata.json (about 12 MB) at +path+, as #download_index.
  def download_errata(path) = download(errata_url, path)

  # The IEN index, ien-index.txt, as a String.
  def ien_index = get("#{@site}/ien/ien-index.txt", max_bytes: TEXT_MAX, deadline: TEXT_DEADLINE).body

  # The listing of the ien/ folder (HTML): which IENs are there as text.
  def ien_listing = get("#{@site}/ien/", max_bytes: TEXT_MAX, deadline: TEXT_DEADLINE).body

  # The bytes of the plain text of RFC +number+ (IEN -+number+).
  def text(number) = get(text_url(number), max_bytes: TEXT_MAX, deadline: TEXT_DEADLINE).body

  private

  def download(url, path)
    FileUtils.mkdir_p(File.dirname(path))
    File.open("#{path}.part", 'wb') { |file| get(url, to: file, max_bytes: INDEX_MAX, deadline: INDEX_DEADLINE) }
    File.rename("#{path}.part", path)
  ensure
    FileUtils.rm_f("#{path}.part")
  end

  # The Response of a successful GET of +url+; an error status raises
  # Rubbs::Common::Web::HTTP::Error.
  def get(url, **)
    response = Rubbs::Common::Web::HTTP.get(url, read_timeout: READ_TIMEOUT, **)
    raise Rubbs::Common::Web::HTTP::Error, "GET #{url}: answered #{response.status}" unless response.ok?

    response
  end
end
