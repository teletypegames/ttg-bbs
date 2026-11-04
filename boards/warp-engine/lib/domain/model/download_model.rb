# frozen_string_literal: true

require 'time'

# A download that went through: when, which title (its key, such as
# <tt>c64/GAME.PRG</tt>), its version and the protocol it went by.
class DownloadModel < BBS::Model
  table :downloads

  # The number of downloads of the title +key+.
  def self.of(key) = where(title: key).count

  # Logs a download of the title +key+. Returns its id.
  def self.add(key, version:, protocol:, at: Time.now.iso8601)
    insert(at: at, title: key, version: version.to_s, protocol: protocol.to_s)
  end
end
