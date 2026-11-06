# frozen_string_literal: true

require 'json'

module Discovery
  # What a call of a board adds up to: the probe, the board's state and next
  # call (StateRules), its banner, software and encoding (BannerAnalyzer),
  # its country (GeoipRepository) and its tags. The prober records its calls
  # here, and the Gate its dials (DialService).
  class ProbeRecorder
    # [tags]   TagService  [geoip] GeoipRepository
    # [config] ConfigRepository (the software signatures)
    def initialize(tags:, geoip:, config:)
      @tags    = tags
      @geoip   = geoip
      @config  = config
    end

    # Records +result+ (a ProbeResultModel) of board +id+, +kind+ scheduled or
    # dial, and updates its state, schedule and tags. A failed dial asks for a
    # probe at once; a dial carries no banner and no telnet options of ours,
    # so it leaves those of the last probe as they are.
    def record(id, result, kind: 'scheduled')
      board = BoardModel.where(id: id).naked.first
      return unless board

      before   = BoardStateModel.of(id) || {}
      analysis = analyse(result)
      ProbeModel.add(id, result, kind: kind, banner_hash: analysis[:banner_hash])
      columns = state_columns(board, before, result, kind)
      columns.merge!(banner_columns(before, result, analysis)) if result.result == 'ok' && !result.banner.empty?
      columns[:options] = JSON.generate(result.options) if result.latency_ms && kind != 'dial'
      BoardStateModel.save(id, **columns)
      @tags.refresh(id, now: result.at)
      columns
    end

    # Records +result+ of a C64-style call of board +id+: the probe (kind
    # c64), what its banner was, and the tags. The state and the schedule
    # are the scheduled calls'.
    def record_c64(id, result)
      return if BoardModel.where(id: id).empty?

      analysis = analyse(result)
      ProbeModel.add(id, result, kind: ProbeModel::C64, banner_hash: analysis[:banner_hash])
      columns = { c64_probe_at: result.at, c64_result: result.result, c64_window: TelnetProbe::C64_TOTAL }
      columns.merge!(c64_banner_columns(result, analysis)) if result.result == 'ok' && !result.banner.empty?
      BoardStateModel.save(id, **columns)
      @tags.refresh(id, now: result.at)
      columns
    end

    # Whether board +id+ gets a C64-style call: a source calls it a PETSCII
    # board, or a call of ours saw PETSCII.
    def c64?(id)
      state = BoardStateModel.of(id) || {}
      [state[:encoding], state[:c64_encoding]].include?('petscii') ||
        TagModel.of(id).include?(TagModel::CLAIMS_PETSCII)
    end

    private

    def analyse(result)
      return {} unless result.result == 'ok'

      encoding = BannerAnalyzer.encoding(result.banner)
      text = BannerAnalyzer.text(result.banner, petscii: encoding == 'petscii')
      {
        encoding:    encoding,
        signature:   BannerAnalyzer.software(text, @config.signatures),
        banner_hash: BannerAnalyzer.digest(result.banner)
      }
    end

    # The state, schedule and address columns of +board+ after +result+.
    def state_columns(board, before, result, kind)
      at = result.at
      first = before[:first_probe_at] || at
      success = result.success? ? at : before[:last_success_at]
      state = state_of(board, result, first, success)
      archived = StateRules.archived?(
        state,
        delisted:        board[:delisted] == 1,
        last_success_at: success,
        first_probe_at:  first,
        now:             at
      )
      {
        state:           state.state,
        success_rate_7d: state.success_rate_7d,
        failures:        state.failures,
        state_since:     before[:state] == state.state ? before[:state_since] || at : at,
        first_probe_at:  first,
        last_probe_at:   at,
        last_result:     result.result,
        last_success_at: success,
        next_probe_at:   next_probe(board, before, state, result, kind, archived),
        archived:        archived ? 1 : 0,
        **address_columns(before, result)
      }
    end

    # The StateRules::Verdict of +board+ by its calls of the last DEAD_AFTER.
    def state_of(board, result, first, success)
      window = ProbeModel.since(board[:id], result.at - StateRules::DEAD_AFTER)
      StateRules.state(window, last_success_at: success, first_probe_at: first, now: result.at)
    end

    # Where the board answered: its IP, the IP's country and the latency,
    # the last known ones when +result+ has none.
    def address_columns(before, result)
      {
        ip:         result.ip || before[:ip],
        country:    (result.ip && @geoip.country(result.ip)) || before[:country],
        latency_ms: result.latency_ms || before[:latency_ms]
      }
    end

    # A successful dial keeps the schedule; a failed one asks for a probe now.
    def next_probe(board, before, state, result, kind, archived)
      return nil if archived
      return result.at if kind == 'dial' && !result.success?
      return before[:next_probe_at] if kind == 'dial' && before[:next_probe_at]
      return result.at + StateRules::DEAD_EVERY if board[:alias_of]

      StateRules.next_probe_at(state, now: result.at)
    end

    def banner_columns(before, result, analysis)
      changed = before[:banner_hash] && before[:banner_hash] != analysis[:banner_hash]
      {
        encoding:          analysis[:encoding],
        software_id:       analysis[:signature]&.id,
        software:          analysis[:signature]&.name,
        banner:            result.banner,
        banner_hash:       analysis[:banner_hash],
        banner_at:         result.at,
        banner_changed_at: changed ? result.at : before[:banner_changed_at]
      }
    end

    def c64_banner_columns(result, analysis)
      {
        c64_encoding:    analysis[:encoding],
        c64_banner:      result.banner,
        c64_banner_hash: analysis[:banner_hash],
        c64_banner_at:   result.at
      }
    end
  end
end
