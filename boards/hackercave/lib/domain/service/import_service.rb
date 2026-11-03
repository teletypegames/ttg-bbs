# frozen_string_literal: true

require 'fileutils'

# Keeps the index fresh: when it is older than the TTL, #refresh downloads
# the RFC Editor's rfc-index.xml and errata.json and the index of the IENs,
# and imports them (IndexRepository#import). The errata and the IENs are
# extras: when they do not come, the RFCs are imported without them.
class ImportService
  def initialize(index:, editor:, index_file:, errata_file:, ttl:)
    @index       = index
    @editor      = editor
    @index_file  = index_file
    @errata_file = errata_file
    @ttl         = ttl
    @importing   = false
    @lock        = Mutex.new
  end

  # Whether the index is older than the TTL, or there is none to read.
  def stale?
    at = @index.imported_at
    at.nil? || !@index.ready? || Time.now - at > @ttl
  end

  # Downloads and imports the index when it is stale (or when +force+).
  # Returns :fresh, :busy (an import is running) or :updated. Raises when
  # the index cannot be downloaded or imported; the old index stays then.
  def refresh(force: false)
    return :fresh unless force || stale?
    return :busy unless @lock.synchronize { !@importing && (@importing = true) }

    begin
      import
    ensure
      @lock.synchronize { @importing = false }
    end
  end

  private

  def import
    started = Time.now
    @editor.download_index(@index_file)
    n = @index.import(@index_file, errata: errata, iens: iens)
    BBS.log('index', format('imported, %<n>d RFCs in %<s>.1f s', n: n, s: Time.now - started))
    GC.start
    :updated
  ensure
    FileUtils.rm_f([@index_file, @errata_file])
  end

  # The path of the downloaded errata.json, or nil.
  def errata
    @editor.download_errata(@errata_file)
    @errata_file
  rescue BBS::HTTP::Error, SystemCallError => e
    BBS.log('index', "errata: #{e.message}")
    nil
  end

  # The IenIndex, or nil.
  def iens
    IenIndex.new(@editor.ien_index, texts: IenIndex.texts_in(@editor.ien_listing))
  rescue BBS::HTTP::Error => e
    BBS.log('index', "IENs: #{e.message}")
    nil
  end
end
