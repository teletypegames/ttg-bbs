# frozen_string_literal: true

require 'fileutils'

# The RFC Editor over HTTP (BBS::HTTP: a deadline, a cap on the body,
# redirects to public http(s) addresses only, the board's User-Agent): the
# index, rfc-index.xml, and the plain text of an RFC as it was published. A
# dead site raises BBS::HTTP::Error, a body over the cap its subclass
# BBS::HTTP::TooLarge.
class RfcEditorRepository
  # The index is about 14 MB.
  INDEX_MAX = 64 * 1024 * 1024
  INDEX_DEADLINE = 300
  # The longest RFCs are about 1 MB of text.
  TEXT_MAX = 4 * 1024 * 1024
  TEXT_DEADLINE = 60
  READ_TIMEOUT  = 30

  # [site]       the base URL of the RFC Editor (https://www.rfc-editor.org)
  # [user_agent] the User-Agent sent with every request
  def initialize(site:, user_agent:)
    @site       = site.delete_suffix('/')
    @user_agent = user_agent
  end

  def index_url = "#{@site}/rfc-index.xml"

  def text_url(number) = "#{@site}/rfc/rfc#{Integer(number)}.txt"

  # Saves the index at +path+, streamed into a temporary file next to it,
  # so the download never sits in memory. Raises BBS::HTTP::Error or
  # SystemCallError; +path+ is then left as it was.
  def download_index(path)
    FileUtils.mkdir_p(File.dirname(path))
    File.open("#{path}.part", 'wb') do |file|
      get(index_url, to: file, max_bytes: INDEX_MAX, deadline: INDEX_DEADLINE)
    end
    File.rename("#{path}.part", path)
  ensure
    FileUtils.rm_f("#{path}.part")
  end

  # The bytes of RFC +number+'s plain text.
  def text(number) = get(text_url(number), max_bytes: TEXT_MAX, deadline: TEXT_DEADLINE).body

  private

  # The Response of a successful GET of +url+; an error status raises
  # BBS::HTTP::Error.
  def get(url, **)
    response = BBS::HTTP.get(url, read_timeout: READ_TIMEOUT, user_agent: @user_agent, **)
    raise BBS::HTTP::Error, "GET #{url}: answered #{response.status}" unless response.ok?

    response
  end
end
