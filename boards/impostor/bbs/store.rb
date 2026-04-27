# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'time'

module BBS
  class Store
    DATA_DIR = File.expand_path('../data', __dir__)
    CSV_FILE = File.join(DATA_DIR, 'sessions.csv')
    HEADERS  = %w[session_id timestamp player_name code feedback email].freeze

    @mutex = Mutex.new

    # Creates or updates the row for session_id with the given fields.
    def self.upsert(session_id:, **fields)
      @mutex.synchronize do
        ensure_file!
        rows = CSV.read(CSV_FILE, headers: true)
        row  = rows.find { |r| r['session_id'] == session_id }

        if row
          fields.each { |k, v| row[k.to_s] = v }
        else
          values = HEADERS.map do |h|
            case h
            when 'session_id' then session_id
            when 'timestamp'  then Time.now.utc.iso8601
            else fields[h.to_sym]
            end
          end
          rows << CSV::Row.new(HEADERS, values)
        end

        CSV.open(CSV_FILE, 'w') do |csv|
          csv << HEADERS
          rows.each { |r| csv << r.fields }
        end
      end
    end

    class << self
      private

      def ensure_file!
        FileUtils.mkdir_p(DATA_DIR)
        return if File.exist?(CSV_FILE)
        CSV.open(CSV_FILE, 'w') { |csv| csv << HEADERS }
      end
    end
  end
end
