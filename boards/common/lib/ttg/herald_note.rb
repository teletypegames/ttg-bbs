# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'time'

module TTG
  # A board's note for the network's day: <tt>data/herald.json</tt> (+board+,
  # +heading+, +title+, +text+, +until+), which TTG Gate BBS reads for its
  # Today tab and the sign-in bulletin (TTG::Bulletin). Written whole (a
  # temporary file renamed over the old), and only when it changed.
  #
  #   TTG::HeraldNote.publish('data/herald.json', 'board' => 'hackercave-bbs', 'heading' => 'Jargon', …)
  module HeraldNote
    # Writes +note+ (a Hash with String keys) to +path+ unless the file holds
    # it already. Returns +:written+, +:same+ or +:none+ (no note).
    def self.publish(path, note)
      return :none unless note
      return :same if read(path) == note

      FileUtils.mkdir_p(File.dirname(path))
      File.write("#{path}.tmp", JSON.generate(note))
      File.rename("#{path}.tmp", path)
      :written
    end

    # The note in +path+ (a Hash), or +nil+.
    def self.read(path)
      File.exist?(path) ? JSON.parse(File.read(path)) : nil
    rescue JSON::ParserError
      nil
    end

    # The next midnight after +at+, local time: until when a note of a day holds.
    def self.day_end(at = Time.now)
      day = at.to_date + 1
      Time.local(day.year, day.month, day.day)
    end
  end
end
