# frozen_string_literal: true

module Discovery
  # The Gate's dial records besides the probes: each refused dial (when, why,
  # which board, which face; nothing of the caller) and each dial's time on
  # the line and the bytes relayed. Both are kept for KEEP; the refusals that
  # go are added to their running totals in meta, so the totals only grow.
  class DialHistoryService
    KEEP = 30 * 86_400
    # The refused dials' reasons (DialService::Refusal) and the faces.
    REASONS = %w[rate busy not_petscii not_public unknown].freeze
    FACES   = %w[modern c64].freeze
    PRUNE_EVERY = 3600
    PRUNED = 'dial_refusals_pruned'

    def initialize
      @pruned_at = 0
    end

    # A refused dial of board +board_id+ (nil for no such board) on +face+.
    def refused(at:, reason:, board_id:, face:)
      DialRefusalModel.insert(at: at.to_i, reason: reason.to_s, board_id: board_id, face: face.to_s)
      prune(at.to_i)
    end

    # A dial that went: its +result+ (a probe result), the +seconds+ it was
    # connected and the +bytes+ the board sent through the Gate.
    def dialled(at:, board_id:, face:, result:, seconds:, bytes:)
      DialModel.insert(at: at.to_i, board_id: board_id, face: face.to_s, result: result.to_s, seconds: seconds.to_i,
                       bytes: bytes.to_i)
      prune(at.to_i)
    end

    # Drops the records older than KEEP at +now+ (at most once in
    # PRUNE_EVERY unless +force+), the refusals' counts into their totals.
    def prune(now, force: false)
      return unless force || now - @pruned_at >= PRUNE_EVERY

      @pruned_at = now
      before = now - KEEP
      DialModel.db.transaction do
        DialRefusalModel.counts_before(before).each do |(reason, face), n|
          MetaModel.add("#{PRUNED}:#{reason}:#{face}", n)
        end
        DialRefusalModel.drop_before(before)
        DialModel.drop_before(before)
      end
    end

    # Every refused dial ever, { [reason, face] => n }, every pair there.
    def refusal_totals
      totals = REASONS.product(FACES).to_h { |pair| [pair, 0] }
      DialRefusalModel.counts.each { |pair, n| totals[pair] = totals.fetch(pair, 0) + n }
      MetaModel.prefixed("#{PRUNED}:").each do |key, value|
        _, reason, face = key.split(':')
        totals[[reason, face]] = totals.fetch([reason, face], 0) + value.to_i
      end
      totals
    end

    # The refused dials since +from+ a reason, every reason there.
    def refusals_since(from)
      counts = DialRefusalModel.reasons_since(from)
      REASONS.to_h { |r| [r, counts.fetch(r, 0)] }.merge(counts)
    end

    # The dials since +from+: how many, their seconds on the line and the
    # bytes relayed, summed.
    def traffic_since(from) = DialModel.traffic_since(from)
  end
end
