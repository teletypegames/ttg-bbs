# frozen_string_literal: true

require 'forwardable'

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
  # Only a PETSCII banner of a call gives it the tag petscii. A board never
  # called so, or called with a shorter window without PETSCII, gets one on
  # its own (+c64_only+ of BoardStateModel.due); a silent one is tried again
  # with every daily round.
  #
  # A C64-style call may take TelnetProbe::C64_TOTAL seconds (slow real C64
  # boards), so they run on C64_CONCURRENCY workers of their own: the
  # scheduled call's worker hands the board over, keeping its claim on the
  # host, and goes back to the pool of +concurrency+. A board waiting for its
  # C64-style call counts in the calls in flight but not against the pool;
  # at most C64_BACKLOG boards wait for a first one alone.
  class ProberService
    extend Forwardable

    CONCURRENCY = 8
    TICK        = 1
    HOUSEKEEPING_EVERY = 3600
    METRICS_EVERY      = 60
    C64_GAP            = 30
    C64_CONCURRENCY    = 2
    C64_BACKLOG        = 4
    # Where a call's line goes by default: the prober's log.
    LOG = ->(line) { BBS.log('probe', line) }

    # [probe]   TelnetProbe (anything with #call(host, port, c64:))
    # [tags]    TagService         [aliases] AliasService
    # [optout]  OptoutRepository   [geoip]   GeoipRepository
    # [config]  ConfigRepository   [metrics] MetricsService, or nil
    def initialize(probe:, tags:, aliases:, optout:, geoip:, config:, metrics: nil, concurrency: CONCURRENCY,
                   c64_gap: C64_GAP, log: LOG)
      @recorder    = ProbeRecorder.new(tags: tags, geoip: geoip, config: config)
      @probe       = probe
      @aliases     = aliases
      @optout      = optout
      @geoip       = geoip
      @metrics     = metrics
      @concurrency = concurrency
      @c64_gap     = c64_gap
      @log         = log
      @busy        = {}
      @c64_stage   = {}
      @mutex       = Mutex.new
    end

    # Runs until +stop+ returns true: dispatches due boards to the workers
    # every TICK seconds, and does the housekeeping. With +limit+, stops after
    # that many calls (a local test run).
    def run(stop: -> { false }, limit: nil)
      queue = Queue.new
      workers = start_workers(queue)
      housekeeping(force: true)
      started = 0
      until stop.call || (limit && started >= limit && idle?)
        housekeeping
        started += dispatch(queue, limit && (limit - started))
        sleep TICK
      end
    ensure
      stop_workers(queue, workers)
    end

    # Records a call of a board (ProbeRecorder).
    def_delegators :@recorder, :record, :record_c64, :c64?

    # Writes the metrics every METRICS_EVERY seconds, and every
    # HOUSEKEEPING_EVERY (or when the opt-out list changed) refreshes the
    # country lookup, the aliases and the opt-outs and prunes old banners.
    def housekeeping(force: false, now: Time.now.to_i)
      write_metrics(now) if force || now - @metrics_at.to_i >= METRICS_EVERY
      return unless force || now - @housekeeping_at.to_i >= HOUSEKEEPING_EVERY || @optout.refresh

      @housekeeping_at = now
      tidy(now)
    rescue StandardError => e
      @log.call("housekeeping: #{e.class}: #{e.message}")
    end

    private

    def idle? = @mutex.synchronize { @busy.empty? }

    # [the scheduled workers on +queue+, the C64-style ones], started.
    def start_workers(queue)
      @c64_queue = Queue.new
      @stopping = false
      [Array.new(@concurrency) { Thread.new { work(queue) } }, Array.new(C64_CONCURRENCY) { Thread.new { work_c64 } }]
    end

    # Closes the queues, the scheduled one first (its workers may still hand
    # a board over), waits for the workers and writes the last metrics.
    def stop_workers(queue, workers)
      @stopping = true
      scheduled, c64 = workers
      queue&.close
      scheduled&.each(&:join)
      @c64_queue&.close
      c64&.each(&:join)
      @metrics&.write(in_flight: 0)
    end

    def write_metrics(now)
      @metrics&.write(in_flight: @mutex.synchronize { @busy.size })
      @metrics_at = now
    end

    def tidy(now)
      @geoip.refresh(Time.at(now).utc)
      @aliases.rebuild
      BoardModel.db.transaction do
        BoardModel.addresses.each { |r| BoardModel.set_optout(r[:id], @optout.level(r[:host], r[:ip])) }
      end
      ProbeModel.prune_banners(now)
    end

    # Puts due boards on +queue+ while a worker is free, one a host and IP.
    # Returns how many.
    def dispatch(queue, limit)
      free = @concurrency - @mutex.synchronize { @busy.size - @c64_stage.size }
      free = [free, limit].min if limit
      return 0 unless free.positive?

      sent = 0
      now = Time.now.to_i
      BoardStateModel.due(now, limit: (free + @concurrency) * 4).each do |row|
        break if sent >= free
        next if row[:c64_only] == 1 && @mutex.synchronize { @c64_stage.size } >= C64_BACKLOG
        next unless claim(row)

        row[:c64_only] == 1 ? hand_over(row, now) : queue << row
        sent += 1
      end
      sent
    end

    # Gives +row+ (claimed) to the C64-style workers, for a call at +at+.
    def hand_over(row, at)
      @mutex.synchronize { @c64_stage[row[:id]] = true }
      @c64_queue << [row, at]
    end

    def release(id)
      @mutex.synchronize do
        @busy.delete(id)
        @c64_stage.delete(id)
      end
    end

    def claim(row)
      keys = ["h:#{row[:host]}", row[:ip] && "i:#{row[:ip]}"].compact
      @mutex.synchronize do
        next false if @busy.key?(row[:id]) || @busy.values.flatten.intersect?(keys)

        @busy[row[:id]] = keys
        true
      end
    end

    # The scheduled calls: a board that answered and wants a C64-style call
    # goes on to the C64-style workers, C64_GAP seconds later, still claimed.
    def work(queue)
      while (row = queue.pop)
        handed = false
        begin
          result = @probe.call(row[:host], row[:port])
          columns = record(row[:id], result)
          @log.call(line(row, result, columns))
          handed = result.success? && c64?(row[:id]) && hand_over(row, Time.now.to_i + @c64_gap)
        rescue StandardError => e
          log_error(row, e)
        ensure
          release(row[:id]) unless handed
        end
      end
    end

    # The C64-style calls, each when its time comes; when the prober stops,
    # the waiting ones are dropped.
    def work_c64
      while (item = @c64_queue.pop)
        row, at = item
        begin
          sleep 0.2 while !@stopping && Time.now.to_i < at
          call_c64(row) unless @stopping
        rescue StandardError => e
          log_error(row, e)
        ensure
          release(row[:id])
        end
      end
    end

    def call_c64(row)
      result = @probe.call(row[:host], row[:port], c64: true)
      columns = record_c64(row[:id], result)
      @log.call(line(row, result, columns && { encoding: columns[:c64_encoding] }, kind: 'c64'))
    end

    def log_error(row, error)
      @log.call("#{row[:host]}:#{row[:port]}: #{error.class}: #{error.message}")
    end

    def line(row, result, columns, kind: nil)
      parts = ["#{row[:host]}:#{row[:port]}#{" #{kind}" if kind}", result.result]
      parts << "#{result.latency_ms}ms" if result.latency_ms
      parts << columns[:encoding] if columns&.dig(:encoding)
      parts << "sw:#{columns[:software_id]}" if columns&.dig(:software_id)
      parts << "-> #{columns[:state]}" if columns&.dig(:state)
      parts.join(' ')
    end
  end
end
