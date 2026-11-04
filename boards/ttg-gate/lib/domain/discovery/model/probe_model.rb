# frozen_string_literal: true

require 'json'

module Discovery
  # One call of a board, kept: a scheduled probe, a C64-style one or a dial
  # of the Gate, its result, timing, address and banner.
  class ProbeModel < BBS::Model
    table :probes, database: :discovery

    # A banner is kept with its probe this long; then only the newest one of a
    # board stays (in board_state), so the history keeps its hashes, not 4 KB
    # a day a board.
    BANNER_DAYS = 30
    # The kind of a C64-style probe.
    C64 = 'c64'

    # Stores +probe+ (a ProbeResultModel) of a board. The banner is kept only
    # when its hash differs from the board's last one of the same kind of
    # call (a C64-style call has a banner of its own). Returns the id.
    def self.add(board_id, probe, kind:, banner_hash:)
      last = BoardStateModel.where(board_id: board_id).get(kind == C64 ? :c64_banner_hash : :banner_hash)
      banner = probe.banner.empty? || banner_hash == last ? nil : Sequel.blob(probe.banner)
      insert(
        board_id:     board_id,
        at:           probe.at,
        kind:         kind,
        result:       probe.result,
        latency_ms:   probe.latency_ms,
        ip:           probe.ip,
        banner:       banner,
        banner_hash:  banner_hash,
        options:      JSON.generate(probe.options),
        duration_ms:  probe.duration_ms,
        banner_bytes: probe.banner.bytesize
      )
    end

    # The probes of a board since +from+ (epoch seconds), oldest first: at,
    # kind and result. The C64-style calls are left out: the state is of the
    # scheduled calls and the dials, one a round.
    def self.since(board_id, from)
      where(board_id: board_id).where { at >= from }.exclude(kind: C64).order(:at, :id).select(:at, :kind, :result).naked.all
    end

    # Every probe of a board since +from+, oldest first: at, kind and result
    # (the uptime strip of its page).
    def self.strip(board_id, from)
      where(board_id: board_id).where { at >= from }.order(:at).select(:at, :kind, :result).naked.all
    end

    # Drops the banners of probes older than BANNER_DAYS at +now+ (the hash
    # stays).
    def self.prune_banners(now)
      exclude(banner: nil).where { at < now - (BANNER_DAYS * 86_400) }.update(banner: nil)
    end

    # The probes (of +kind+, or of any) since +from+ a result: { 'ok' => n, … }.
    def self.result_counts(from, kind: nil)
      rows = where { at >= from }
      rows = rows.where(kind: kind) if kind
      rows.group_and_count(:result).as_hash(:result, :count)
    end

    # When the last probe was made, nil before the first.
    def self.last_at = max(:at)

    # Every stored probe a result and kind: { [result, kind] => n }.
    def self.totals = group_and_count(:result, :kind).to_hash(%i[result kind], :count)

    # The scheduled probes since +from+ a result: their average whole-call
    # time in ms ({ 'ok' => avg, … }), and the longest.
    def self.durations(from)
      calls = where { at >= from }.where(kind: 'scheduled').exclude(duration_ms: nil).group(:result)
      rows = calls.select(:result, Sequel.function(:avg, :duration_ms).as(:avg), Sequel.function(:max, :duration_ms).as(:max))
        .naked.all
      [rows.to_h { |r| [r[:result], r[:avg]] }, rows.map { |r| r[:max] }.max]
    end

    # The average banner of the scheduled probes since +from+ that read one,
    # in bytes (nil without one).
    def self.banner_bytes(from)
      where { at >= from }.where(kind: 'scheduled', banner_bytes: 1..).avg(:banner_bytes)
    end

    # Every stored probe a result, the commonest first: [result, n] pairs.
    def self.results = group_and_count(:result).reverse(:count).naked.map { |r| [r[:result], r[:count]] }
  end
end
