# frozen_string_literal: true

require 'json'

module Discovery
  # Everything the board page of the Gate shows (::of):
  # the listing, the fields with the source each came from, the 30-day uptime
  # strip, and the banners for the preview: the one of the scheduled call
  # (an ANSI terminal's) and the one of the C64-style call.
  #
  # [listing]  its ListingModel
  # [board]    its boards row (a Hash)
  # [state]    its board_state row (a Hash), or {}
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

    # The page of board +id+ at +now+, nil when it is not shown.
    def self.of(id, now: Time.now.to_i)
      listing = ListingModel.find(id)
      return unless listing

      new(
        listing: listing,
        board:   BoardModel.where(id: id).naked.first,
        state:   BoardStateModel.of(id) || {},
        sources: BoardSourceModel.listed(id),
        probes:  ProbeModel.strip(id, now - ((STRIP_DAYS + 1) * 86_400))
      )
    end

    # The shown fields that have a value, each with the name of its source:
    # a list's name, "our call" for what the banner said, "DB-IP" for the
    # country.
    def fields
      list = listed_fields
      list.insert(1, software_field) if software_field
      list << Field.new(label: 'Country', value: state[:country].upcase, source: 'DB-IP') if state[:country]
      list << Field.new(label: 'Encoding', value: encodings, source: 'our call') if encoding || c64_encoding
      list
    end

    # The fields the lists gave, each with the list it came from.
    def listed_fields
      provenance = JSON.parse(board[:provenance] || '{}')
      %i[name sysop location since ftn_address hardware website].filter_map do |key|
        value = board[key]
        Field.new(label: LABELS.fetch(key), value: value.to_s, source: source_name(provenance[key.to_s])) if value
      end
    end

    LABELS = {
      name:        'Name',
      sysop:       'Sysop',
      location:    'Location',
      since:       'Since',
      ftn_address: 'FTN address',
      software:    'Software',
      hardware:    'Hardware',
      website:     'Website'
    }.freeze
    ENCODINGS = %w[ansi petscii atascii ascii].freeze

    def ftn_address = board[:ftn_address]

    # The encoding the banner of our last call showed, nil when unknown.
    def encoding = ENCODINGS.include?(state[:encoding]) ? state[:encoding] : nil

    # The encoding the banner of our last C64-style call showed, nil when
    # unknown or never called so.
    def c64_encoding = ENCODINGS.include?(state[:c64_encoding]) ? state[:c64_encoding] : nil

    # The Encoding field: the scheduled call's, and the C64-style call's when
    # it differs ("ansi, petscii to a C64").
    def encodings
      return "#{c64_encoding} to a C64" unless encoding
      return encoding if c64_encoding.nil? || c64_encoding == encoding

      "#{encoding}, #{c64_encoding} to a C64"
    end

    def last_success_at = state[:last_success_at]

    def last_result = state[:last_result]

    def latency_ms = state[:latency_ms]

    def delisted? = board[:delisted] == 1

    # The stored banner (the newest of a successful probe), binary, or nil
    # when there is none or its sysop opted out of the preview.
    def banner
      return unless listing.preview?

      bytes(state[:banner])
    end

    def banner_at = state[:banner_at]

    # The PETSCII banner for the C64 face: the C64-style call's, else the
    # scheduled call's when that was PETSCII; nil without one, or when its
    # sysop opted out of the preview.
    def c64_banner
      return unless listing.preview?
      return bytes(state[:c64_banner]) if c64_encoding == 'petscii'

      banner if encoding == 'petscii'
    end

    def c64_banner_at = c64_encoding == 'petscii' ? state[:c64_banner_at] : banner_at

    # The uptime strip of the last STRIP_DAYS days, the oldest first, today
    # last, a day by +utc_offset+'s calendar: UP when a probe or a dial
    # succeeded that day, DOWN when they all failed, NONE without one.
    def strip(now = Time.now.to_i, utc_offset: Time.now.utc_offset)
      today = (now + utc_offset) / 86_400
      days = Array.new(STRIP_DAYS, NONE)
      probes.each do |p|
        slot = STRIP_DAYS - 1 - (today - ((p[:at] + utc_offset) / 86_400))
        next unless slot.between?(0, STRIP_DAYS - 1)

        days[slot] = UP if StateRules.success?(p)
        days[slot] = DOWN if days[slot] == NONE
      end
      days.join
    end

    # The lists that name it, by name: the active ones.
    def source_names = sources.select { |s| s[:active] == 1 }.map { |s| s[:name] || s[:source_id] }

    private

    def bytes(blob) = blob.nil? || blob.empty? ? nil : blob.b

    def software_field
      return Field.new(label: 'Software', value: state[:software], source: 'our call') if state[:software]
      return unless board[:software]

      provenance = JSON.parse(board[:provenance] || '{}')
      Field.new(label: 'Software', value: board[:software], source: source_name(provenance['software']))
    end

    def source_name(id)
      return unless id

      name = sources.find { |s| s[:source_id] == id }&.dig(:name) || id
      name.sub(/\s*\([^)]*\)\z/, '')
    end
  end
end
