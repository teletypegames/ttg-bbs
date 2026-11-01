# frozen_string_literal: true

require 'json'

module Discovery
  # The prober (bin/discovery-prober, the ttg-gate-bbs-prober service): calls
  # the boards that are due, records each call and what it adds up to
  # (StateRules, BannerAnalyzer, the country), and keeps the catalog tidy.
  #
  # Politeness (TTG_DISCOVERY.md §5.2): at most +concurrency+ (8) calls at
  # once, at most one a host and one an IP address; the next call of a board
  # comes from StateRules; hidden boards (opt-out) and archived ones are never
  # called; an alias is called weekly only, to notice when its IP moves.
  #
  # The C64-style call (TTG_DISCOVERY.md §5.1): a board a source calls a
  # PETSCII board (the tag claims:petscii) or that showed PETSCII is called a
  # second time after its scheduled call answered, C64_GAP seconds later
  # (a real C64 board has one line, and needs a while after a hang-up) on
  # the same claim of its host, as a Commodore 64 would call it (no telnet).
  # Only a PETSCII banner of a call gives it the tag petscii. A board of
  # before the C64-style call gets its first one on its own (+c64_only+ of
  # ProbeRepository#due).
  class ProberService
    CONCURRENCY = 8
    TICK        = 1
    HOUSEKEEPING_EVERY = 3600
    METRICS_EVERY      = 60
    C64_GAP            = 30

    # [catalog] CatalogRepository  [probes] ProbeRepository
    # [probe]   TelnetProbe (anything with #call(host, port, c64:))
    # [tags]    TagService         [aliases] AliasService
    # [optout]  OptoutRepository   [geoip]   GeoipRepository
    # [config]  ConfigRepository   [metrics] MetricsService, or nil
    def initialize(catalog:, probes:, probe:, tags:, aliases:, optout:, geoip:, config:, metrics: nil,
                   concurrency: CONCURRENCY, c64_gap: C64_GAP, log: ->(line) { $stdout.puts(line) })
      @catalog     = catalog
      @probes      = probes
      @probe       = probe
      @tags        = tags
      @aliases     = aliases
      @optout      = optout
      @geoip       = geoip
      @config      = config
      @metrics     = metrics
      @concurrency = concurrency
      @c64_gap     = c64_gap
      @log         = log
      @busy        = {}
      @mutex       = Mutex.new
    end

    # Runs until +stop+ returns true: dispatches due boards to the workers
    # every TICK seconds, and does the housekeeping. With +limit+, stops after
    # that many calls (a local test run).
    def run(stop: -> { false }, limit: nil)
      queue = Queue.new
      started = 0
      workers = Array.new(@concurrency) { Thread.new { work(queue) } }
      housekeeping(force: true)
      until stop.call || (limit && started >= limit && idle?)
        housekeeping
        started += dispatch(queue, limit && (limit - started))
        sleep TICK
      end
    ensure
      queue&.close
      workers&.each(&:join)
      @metrics&.write(in_flight: 0)
    end

    # Records +result+ (a ProbeResultModel) of board +id+, +kind+ scheduled or
    # dial, and updates its state, schedule and tags. A failed dial asks for a
    # probe at once; a dial carries no banner and no telnet options of ours,
    # so it leaves those of the last probe as they are.
    def record(id, result, kind: 'scheduled')
      board = @catalog.board(id)
      return unless board

      before   = @probes.state(id) || {}
      analysis = analyse(result)
      @probes.add(id, result, kind: kind, banner_hash: analysis[:banner_hash])
      columns = state_columns(board, before, result, kind)
      columns.merge!(banner_columns(before, result, analysis)) if result.result == 'ok' && !result.banner.empty?
      columns[:options] = JSON.generate(result.options) if result.latency_ms && kind != 'dial'
      @probes.save_state(id, **columns)
      @tags.refresh(id, now: result.at)
      columns
    end

    # Records +result+ of a C64-style call of board +id+: the probe (kind
    # c64), what its banner was, and the tags. The state and the schedule
    # are the scheduled calls'.
    def record_c64(id, result)
      return unless @catalog.board(id)

      analysis = analyse(result)
      @probes.add(id, result, kind: ProbeRepository::C64, banner_hash: analysis[:banner_hash])
      columns = { c64_probe_at: result.at, c64_result: result.result }
      if result.result == 'ok' && !result.banner.empty?
        columns.merge!(c64_encoding: analysis[:encoding], c64_banner: result.banner,
                       c64_banner_hash: analysis[:banner_hash], c64_banner_at: result.at)
      end
      @probes.save_state(id, **columns)
      @tags.refresh(id, now: result.at)
      columns
    end

    # Whether board +id+ gets a C64-style call: a source calls it a PETSCII
    # board, or a call of ours saw PETSCII.
    def c64?(id)
      state = @probes.state(id) || {}
      [state['encoding'], state['c64_encoding']].include?('petscii') ||
        @catalog.tags(id).include?(ProbeRepository::CLAIMS_PETSCII)
    end

    def housekeeping(force: false, now: Time.now.to_i)
      if force || now - @metrics_at.to_i >= METRICS_EVERY
        @metrics&.write(in_flight: @mutex.synchronize { @busy.size })
        @metrics_at = now
      end
      return unless force || now - @housekeeping_at.to_i >= HOUSEKEEPING_EVERY || @optout.refresh

      @housekeeping_at = now
      @geoip.refresh(Time.at(now).utc)
      @aliases.rebuild
      @catalog.transaction do
        @catalog.addresses.each { |r| @catalog.set_optout(r['id'], @optout.level(r['host'], r['ip'])) }
      end
      @probes.prune_banners(now)
    rescue StandardError => e
      @log.call("ttg-gate-bbs-prober: housekeeping: #{e.class}: #{e.message}")
    end

    private

    def idle? = @mutex.synchronize { @busy.empty? }

    # Puts due boards on +queue+ while a worker is free, one a host and IP.
    # Returns how many.
    def dispatch(queue, limit)
      free = @concurrency - @mutex.synchronize { @busy.size }
      free = [free, limit].min if limit
      return 0 unless free.positive?

      sent = 0
      @probes.due(Time.now.to_i, limit: (free + @concurrency) * 4).each do |row|
        break if sent >= free
        next unless claim(row)

        queue << row
        sent += 1
      end
      sent
    end

    def claim(row)
      keys = ["h:#{row['host']}", row['ip'] && "i:#{row['ip']}"].compact
      @mutex.synchronize do
        next false if @busy.key?(row['id']) || @busy.values.flatten.intersect?(keys)

        @busy[row['id']] = keys
        true
      end
    end

    def work(queue)
      while (row = queue.pop)
        begin
          call(row)
        rescue StandardError => e
          @log.call("ttg-gate-bbs-prober: #{row['host']}:#{row['port']}: #{e.class}: #{e.message}")
        ensure
          @mutex.synchronize { @busy.delete(row['id']) }
        end
      end
    end

    # The scheduled call of +row+, and the C64-style one after it when the
    # board answered and wants one; only the C64-style call for a c64_only
    # row.
    def call(row)
      unless row['c64_only'] == 1
        result = @probe.call(row['host'], row['port'])
        columns = record(row['id'], result)
        @log.call(line(row, result, columns))
        return unless result.success? && c64?(row['id'])

        sleep @c64_gap
      end
      result = @probe.call(row['host'], row['port'], c64: true)
      columns = record_c64(row['id'], result)
      @log.call(line(row, result, columns && { encoding: columns[:c64_encoding] }, kind: 'c64'))
    end

    def line(row, result, columns, kind: nil)
      parts = ["ttg-gate-bbs-prober: #{row['host']}:#{row['port']}#{" #{kind}" if kind}", result.result]
      parts << "#{result.latency_ms}ms" if result.latency_ms
      parts << columns[:encoding] if columns&.dig(:encoding)
      parts << "sw:#{columns[:software_id]}" if columns&.dig(:software_id)
      parts << "-> #{columns[:state]}" if columns&.dig(:state)
      parts.join(' ')
    end

    def analyse(result)
      return {} unless result.result == 'ok'

      encoding = BannerAnalyzer.encoding(result.banner)
      text = BannerAnalyzer.text(result.banner, petscii: encoding == 'petscii')
      { encoding: encoding, signature: BannerAnalyzer.software(text, @config.signatures),
        banner_hash: BannerAnalyzer.digest(result.banner) }
    end

    def state_columns(board, before, result, kind)
      at = result.at
      first = before['first_probe_at'] || at
      success = result.success? ? at : before['last_success_at']
      window = @probes.since(board['id'], at - StateRules::DEAD_AFTER)
      state = StateRules.state(window, last_success_at: success, first_probe_at: first, now: at)
      archived = StateRules.archived?(state, delisted: board['delisted'] == 1, last_success_at: success,
                                             first_probe_at: first, now: at)
      { state: state.state, success_rate_7d: state.success_rate_7d, failures: state.failures,
        state_since: before['state'] == state.state ? before['state_since'] || at : at,
        first_probe_at: first, last_probe_at: at, last_result: result.result, last_success_at: success,
        next_probe_at: next_probe(board, before, state, result, kind, archived), archived: archived ? 1 : 0,
        ip: result.ip || before['ip'], country: (result.ip && @geoip.country(result.ip)) || before['country'],
        latency_ms: result.latency_ms || before['latency_ms'] }
    end

    # A successful dial keeps the schedule; a failed one asks for a probe now.
    def next_probe(board, before, state, result, kind, archived)
      return nil if archived
      return result.at if kind == 'dial' && !result.success?
      return before['next_probe_at'] if kind == 'dial' && before['next_probe_at']
      return result.at + StateRules::DEAD_EVERY if board['alias_of']

      StateRules.next_probe_at(state, now: result.at)
    end

    def banner_columns(before, result, analysis)
      changed = before['banner_hash'] && before['banner_hash'] != analysis[:banner_hash]
      { encoding: analysis[:encoding], software_id: analysis[:signature]&.id, software: analysis[:signature]&.name,
        banner: result.banner, banner_hash: analysis[:banner_hash], banner_at: result.at,
        banner_changed_at: changed ? result.at : before['banner_changed_at'] }
    end
  end
end
