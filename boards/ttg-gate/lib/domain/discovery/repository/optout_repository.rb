# frozen_string_literal: true

require 'yaml'

module Discovery
  # config/discovery-optout.yml: the hosts and IP addresses whose sysops asked
  # to be left out (hide) or to have no banner preview (no_preview). Read
  # again when the file changes; a file that cannot be read keeps the last
  # good list (and warns), so a typo never un-hides a board.
  class OptoutRepository
    LEVELS = %w[hide no_preview].freeze

    def initialize(path)
      @path  = path
      @mtime = nil
      @list  = { 'hide' => [], 'no_preview' => [] }
    end

    # The level of a board (+host+, or its +ip+): 'hide', 'no_preview' or nil.
    def level(host, ip = nil)
      refresh
      keys = [host, ip].compact.map(&:downcase)
      LEVELS.find { |l| @list[l].intersect?(keys) }
    end

    # Whether the file changed since the last read (and reads it).
    def refresh
      mtime = File.mtime(@path)
      return false if mtime == @mtime

      data = YAML.safe_load_file(@path) || {}
      @list  = LEVELS.to_h { |l| [l, Array(data[l]).map { |e| e.to_s.strip.downcase.chomp('.') }] }
      @mtime = mtime
      true
    rescue SystemCallError, Psych::Exception => e
      warn "ttg-gate-bbs-discovery: cannot read #{@path}: #{e.message}"
      false
    end
  end
end
