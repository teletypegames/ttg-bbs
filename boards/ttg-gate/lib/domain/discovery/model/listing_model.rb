# frozen_string_literal: true

module Discovery
  # One board as a list of the Gate shows it: a row of the catalog with its
  # state and tags (DirectoryRepository#listings).
  #
  # [state]           online, flaky, down, dead or unknown
  # [software]        the banner's software, else the source's text
  # [country]         ISO code, lowercase, or nil
  # [last_success_at] its last successful probe or dial, or nil
  # [first_probe_at]  its first probe, or nil
  # [first_seen_at]   when a source first named it
  # [state_since]     when it turned its state
  # [tags]            its tags (TagService), sorted
  # [optout]          nil, or no_preview (hidden boards never get here)
  class ListingModel < Data.define(:id, :host, :port, :name, :state, :software, :country, :last_success_at,
                                   :first_probe_at, :first_seen_at, :state_since, :tags, :optout)
    # The mark of a state on the modern face (TTG_DISCOVERY.md §5.3); the C64
    # draws its own glyphs (UI::Petscii::Marks).
    MARKS = { 'online' => '●', 'flaky' => '◐', 'down' => '✗', 'dead' => '†', 'unknown' => '?' }.freeze
    # The order of a list: online first, then by name.
    RANK = { 'online' => 0, 'flaky' => 1, 'down' => 2, 'unknown' => 3, 'dead' => 4 }.freeze
    ENCODINGS = %w[ansi petscii atascii ascii].freeze
    DAY  = 86_400
    HOUR = 3600

    def self.from(row)
      new(id: row['id'], host: row['host'], port: row['port'], name: row['name'],
          state: row['state'] || 'unknown', software: row['software'], country: row['country'],
          last_success_at: row['last_success_at'], first_probe_at: row['first_probe_at'],
          first_seen_at: row['first_seen_at'], state_since: row['state_since'],
          tags: row['tags'].to_s.split.sort.freeze, optout: row['optout'])
    end

    # The name, or the host when no source gave one.
    def title = name.to_s.empty? ? host : name

    def address = "#{host}:#{port}"

    def mark = MARKS.fetch(state, '?')

    def dead? = state == 'dead'

    def petscii? = tags.include?('petscii')

    def ascii? = tags.include?('ascii')

    # Whether a Commodore 64 can call it: in PETSCII, or in plain ASCII
    # through the gate's translation (#translated_for_c64?).
    def c64? = petscii? || ascii?

    # Whether a C64's call goes through the gate's translation (an ASCII
    # board without PETSCII; BBS::Gateway::AsciiBridge).
    def translated_for_c64? = ascii? && !petscii?

    # A board for a Commodore only: PETSCII, and no other encoding seen.
    def petscii_only? = petscii? && !tags.intersect?(ENCODINGS - ['petscii'])

    def preview? = optout != 'no_preview'

    def sort_key = [RANK.fetch(state, 3), title.downcase, port]

    # How long it has not answered, for the list: "down for 3 days",
    # "no answer for 45 days", "never answered", "not called yet"; empty for
    # an answering board.
    def status(now = Time.now.to_i)
      case state
      when 'down' then last_success_at ? "down for #{ListingModel.ago(now - last_success_at)}" : 'never answered'
      when 'dead' then last_success_at ? "no answer for #{ListingModel.ago(now - last_success_at)}" : 'never answered'
      when 'unknown' then 'not called yet'
      when 'flaky' then 'flaky'
      else ''
      end
    end

    # +seconds+ in words: "5 hours", "1 day", "3 days".
    def self.ago(seconds)
      return 'an hour' if seconds < 2 * HOUR
      return "#{seconds / HOUR} hours" if seconds < 2 * DAY

      "#{seconds / DAY} days"
    end
  end
end
