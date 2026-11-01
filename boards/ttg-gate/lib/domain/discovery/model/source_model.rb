# frozen_string_literal: true

module Discovery
  # One list of config/discovery/sources.yml.
  SourceModel = Data.define(:id, :name, :url, :format, :member, :network, :licence, :attribution, :enabled) do
    def self.from(record)
      new(id:          record.fetch('id').to_s,
          name:        record.fetch('name').to_s,
          url:         record.fetch('url').to_s,
          format:      record.fetch('format').to_s,
          member:      record['member'] && Regexp.new(record['member'], Regexp::IGNORECASE),
          network:     record['network']&.to_s,
          licence:     record['licence'].to_s,
          attribution: record['attribution'].to_s,
          enabled:     record['enabled'] != false)
    end

    def enabled? = enabled
  end
end
