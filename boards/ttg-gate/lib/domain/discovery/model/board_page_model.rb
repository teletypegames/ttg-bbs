# frozen_string_literal: true

require 'json'

module Discovery
  # Everything the board page of the Gate shows (DirectoryRepository#page):
  # the listing, the fields with the source each came from, the 30-day uptime
  # strip, and the banner for the preview.
  #
  # [listing]  its ListingModel
  # [board]    its boards row
  # [state]    its board_state row, or {}
  # [sources]  its board_sources rows joined with sources: source_id, name,
  #            attribution, active
  # [probes]   its probes of the last STRIP_DAYS days: at, kind, result
  class BoardPageModel < Data.define(:listing, :board, :state, :sources, :probes)
    STRIP_DAYS = 30
    # A day of the strip: a success, only failures, no probe.
    UP   = '█'
    DOWN = '·'
    NONE = ' '
    Field = Data.define(:label, :value, :source)

    # The shown fields that have a value, each with the name of its source:
    # a list's name, "our call" for what the banner said, "DB-IP" for the
    # country.
    def fields
      provenance = JSON.parse(board['provenance'] || '{}')
      list = %w[name sysop location since ftn_address].filter_map do |key|
        value = board[key]
        Field.new(label: LABELS.fetch(key), value: value.to_s, source: source_name(provenance[key])) if value
      end
      list.insert(1, software_field) if software_field
      list << Field.new(label: 'Country', value: state['country'].upcase, source: 'DB-IP') if state['country']
      list << Field.new(label: 'Encoding', value: state['encoding'], source: 'our call') if encoding
      list
    end

    LABELS = { 'name' => 'Name', 'sysop' => 'Sysop', 'location' => 'Location', 'since' => 'Since',
               'ftn_address' => 'FTN address', 'software' => 'Software' }.freeze

    def ftn_address = board['ftn_address']

    # The encoding the banner of our last call showed, nil when unknown.
    def encoding = %w[ansi petscii atascii ascii].include?(state['encoding']) ? state['encoding'] : nil

    def last_success_at = state['last_success_at']

    def last_result = state['last_result']

    def latency_ms = state['latency_ms']

    def delisted? = board['delisted'] == 1

    # The stored banner (the newest of a successful probe), binary, or nil
    # when there is none or its sysop opted out of the preview.
    def banner
      return unless listing.preview?

      bytes = state['banner']
      bytes.nil? || bytes.empty? ? nil : bytes.b
    end

    def banner_at = state['banner_at']

    # The uptime strip of the last STRIP_DAYS days, the oldest first, today
    # last, a day by +utc_offset+'s calendar: UP when a probe or a dial
    # succeeded that day, DOWN when they all failed, NONE without one.
    def strip(now = Time.now.to_i, utc_offset: Time.now.utc_offset)
      today = (now + utc_offset) / 86_400
      days = Array.new(STRIP_DAYS, NONE)
      probes.each do |p|
        slot = STRIP_DAYS - 1 - (today - ((p['at'] + utc_offset) / 86_400))
        next unless slot.between?(0, STRIP_DAYS - 1)

        days[slot] = UP if StateRules.success?(p)
        days[slot] = DOWN if days[slot] == NONE
      end
      days.join
    end

    # The lists that name it, by name: the active ones.
    def source_names = sources.select { |s| s['active'] == 1 }.map { |s| s['name'] || s['source_id'] }

    private

    def software_field
      return Field.new(label: 'Software', value: state['software'], source: 'our call') if state['software']
      return unless board['software']

      provenance = JSON.parse(board['provenance'] || '{}')
      Field.new(label: 'Software', value: board['software'], source: source_name(provenance['software']))
    end

    def source_name(id)
      return unless id

      sources.find { |s| s['source_id'] == id }&.dig('name') || id
    end
  end
end
