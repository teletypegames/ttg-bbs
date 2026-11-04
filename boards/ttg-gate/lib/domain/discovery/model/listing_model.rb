# frozen_string_literal: true

module Discovery
  # One board as a list of the Gate shows it: a row of the catalog with its
  # state and tags (::matching). Aliases and hidden boards (opt-out) are
  # never one.
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

    # The columns of a listing, of the boards a list may show.
    COLUMNS = <<~SQL
      SELECT b.id, b.host, b.port, b.name, b.first_seen_at, b.optout,
             COALESCE(s.state, 'unknown') AS state, s.state_since, s.last_success_at, s.first_probe_at,
             COALESCE(s.software, b.software) AS software, s.country,
             (SELECT group_concat(t.tag, ' ') FROM tags t WHERE t.board_id = b.id) AS tags
      FROM boards b LEFT JOIN board_state s ON s.board_id = b.id
      WHERE b.alias_of IS NULL AND (b.optout IS NULL OR b.optout != 'hide')
    SQL

    def self.from(row)
      new(id: row[:id], host: row[:host], port: row[:port], name: row[:name],
          state: row[:state] || 'unknown', software: row[:software], country: row[:country],
          last_success_at: row[:last_success_at], first_probe_at: row[:first_probe_at],
          first_seen_at: row[:first_seen_at], state_since: row[:state_since],
          tags: row[:tags].to_s.split.sort.freeze, optout: row[:optout])
    end

    # The listings a ListingFilter lets through, unsorted. An FTS query the
    # index cannot read gives none.
    def self.matching(filter)
      where = conditions(filter)
      sql = COLUMNS + where.map { |condition| " AND #{condition.first}" }.join
      BoardModel.db.fetch(sql, *where.flat_map { |condition| condition.drop(1) }).map { |row| from(row) }
    rescue Sequel::DatabaseError => e
      raise unless filter.match && e.message.match?(/fts5|syntax|MATCH/i)

      []
    end

    # The listing of board +id+, nil when it is not shown.
    def self.find(id)
      row = BoardModel.db.fetch("#{COLUMNS} AND b.id = ?", id).first
      row && from(row)
    end

    # The conditions of +filter+, each [SQL, its arguments…].
    def self.conditions(filter)
      list = []
      list << ["COALESCE(s.state, 'unknown') != 'dead'"] unless filter.dead
      list << ["COALESCE(s.state, 'unknown') = ?", filter.state] if filter.state
      list << ["b.id NOT IN (SELECT board_id FROM tags WHERE tag = '#{ListingFilter::MAILER}')"] unless filter.mailers
      list << tags_condition(filter)
      list << ['b.id IN (SELECT rowid FROM boards_fts WHERE boards_fts MATCH ?)', filter.match] if filter.match
      list.compact
    end

    # Every tag of +filter+ (petscii too, when asked), or nil.
    def self.tags_condition(filter)
      tags = (filter.tags + (filter.petscii ? ['petscii'] : [])).uniq
      return if tags.empty?

      ["b.id IN (SELECT board_id FROM tags WHERE tag IN (#{(['?'] * tags.size).join(', ')}) " \
       'GROUP BY board_id HAVING COUNT(*) = ?)', *tags, tags.size]
    end
    private_class_method :conditions, :tags_condition

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
