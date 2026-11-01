# frozen_string_literal: true

require 'fileutils'
require 'ipaddr'
require 'json'
require 'socket'

module Discovery
  # The rules of dialling a board of the catalog from the Gate
  # (TTG_DISCOVERY.md §8.4), and the record of each dial:
  #
  # - only a board of the catalog, by its id: there is no free host:port, so
  #   the Gate is no open telnet relay; and only on the public internet: the
  #   name is resolved once, every address must be public (Address.callable?),
  #   and the line goes to that address, so a name that changes its answer
  #   meanwhile cannot turn the Gate inward;
  # - at most +per_caller+ dials in +window+ seconds a caller (an IPv6 one
  #   by its /64), at most +per_host+ connections at once from the Gate to
  #   one address the board's name resolved to (two names of one machine
  #   share them), and a line silent both ways for +idle+ seconds ends
  #   (PER_CALLER, WINDOW, PER_HOST and IDLE by default; Root reads them
  #   from the environment);
  # - the C64 face dials PETSCII boards only; the modern face warns before a
  #   board made for a C64 only, and either warns before a dead board;
  # - the outcome is recorded as a probe of kind dial (ProberService#record),
  #   and a failed one asks the prober for a probe at once; its time on the
  #   line and the bytes relayed, and every refused dial, go to +history+
  #   (DialRepository).
  #
  # The dials in progress go to +live_path+ (JSON, rewritten on each change)
  # with the limits, the lines to the busiest host and each caller's dial
  # times in the window (no caller's address), which the prober's
  # MetricsService adds to the metrics.
  class DialService
    WINDOW     = 600
    PER_CALLER = 10
    PER_HOST   = 3
    IDLE       = 600
    LIMITS     = { window: WINDOW, per_caller: PER_CALLER, per_host: PER_HOST, idle: IDLE }.freeze
    # Seconds to wait for a board to accept the call: as long as a probe.
    CONNECT_TIMEOUT = TelnetProbe::CONNECT_TIMEOUT

    # Why a dial is refused: +rate+ (the caller dialled PER_CALLER times in
    # WINDOW; +wait+ seconds until the next one), +busy+ (PER_HOST lines to
    # the host are taken), +not_petscii+ (a C64 caller, a board without
    # PETSCII), +not_public+ (the board's name resolves to no address on the
    # public internet) or +unknown+ (no such board in the catalog).
    Refusal = Data.define(:reason, :wait)

    # One dial in progress: the caller's line hands the gateway's report to
    # it (BBS::Gateway::Report: connected, error, address, connect_seconds,
    # received, hung_up).
    class Call
      attr_accessor :report, :ended_at
      attr_reader :board, :at, :face, :ip

      def initialize(board, at, face = :modern, ip: nil)
        @board = board
        @at    = at
        @face  = face
        @ip    = ip
      end

      # The seconds the line was connected to the board, whole.
      def seconds
        return 0 unless report&.connected && ended_at

        [(ended_at - at - report.connect_seconds.to_f).round, 0].max
      end
    end

    # The face a record names: modern or c64.
    def self.face(face) = face.to_s == 'petscii' ? 'c64' : face.to_s

    attr_reader :window, :per_caller, :per_host, :idle

    # [recorder]  ProberService (anything with #record(id, result, kind:))
    # [history]   DialRepository, or nil
    # [live_path] the JSON file of the live dials, or nil
    # [resolver]  host → its IP addresses (TelnetProbe#resolve)
    # [limits]    window:, per_caller:, per_host:, idle: (LIMITS by default)
    def initialize(recorder:, history: nil, live_path: nil, clock: -> { Time.now.to_f }, log: ->(line) { warn line },
                   resolver: TelnetProbe.new.method(:resolve), callable: Address.method(:callable?), **limits)
      @recorder  = recorder
      @history   = history
      @live_path = live_path
      @clock     = clock
      @log       = log
      @resolver  = resolver
      @callable  = callable
      @window, @per_caller, @per_host, @idle = LIMITS.merge(limits).values_at(*LIMITS.keys)
      @mutex = Mutex.new
      @file  = Mutex.new
      @dials = Hash.new { |h, k| h[k] = [] }
      @lines = Hash.new(0)
      write_live
    end

    # The key a caller is counted by: its IP address (BBS::RateLimit's
    # rule), an IPv6 one by its /64, which one machine usually holds whole;
    # a line from a local address (bbsweb on the same host carries all its
    # callers from one) counts by its session.
    def self.caller_key(ip, session_id)
      addr = BBS::Address.parse(ip)
      return "line:#{session_id}" if addr.nil? || BBS::Address.local?(addr)

      addr.ipv6? ? "#{addr.mask(64)}/64" : addr.to_s
    end

    # The warnings before dialling +board+ (a ListingModel) on +face+
    # (:modern or :petscii): :petscii_only (a board for a C64, on a modern
    # terminal), :dead (no answer for 30 days).
    def warnings(board, face:)
      list = []
      list << :petscii_only if face == :modern && board.petscii_only?
      list << :dead if board.dead?
      list
    end

    # The Refusal of a dial of +board+ by +caller+ now, nil when it may go.
    def check(caller, board, face:)
      now = @clock.call
      ips = resolve(board)
      refused(@mutex.synchronize { refusal(caller, board, face, now, ips) }, board, face, now)
    end

    # Dials +board+ for +caller+: when the rules let it, counts the dial,
    # yields a Call (the block puts the gateway's report on it, and connects
    # to its +ip+, never to the name), records the outcome and returns the
    # Call; else returns the Refusal and yields nothing. The lines are freed
    # and the outcome recorded also when the caller hangs up inside (the
    # IOError goes on).
    def dial(caller, board, face:)
      now = @clock.call
      ips = resolve(board)
      refusal = @mutex.synchronize { refusal(caller, board, face, now, ips) || take(caller, ips.first, now) }
      return refused(refusal, board, face, now) if refusal

      write_live
      call = Call.new(board, now.to_i, face, ip: ips.first)
      begin
        yield call
        call
      ensure
        hang_up(call)
      end
    end

    # The dials in progress.
    def live = @mutex.synchronize { @lines.values.sum }

    # The probe result of a gateway's report: ok when the board sent
    # something, silent when it did not but the line stayed up until the
    # caller left, closed when it hung up without a byte; dns_fail, refused or
    # timeout when it did not connect.
    def self.result(report)
      if report.connected
        return 'ok' if report.received.to_i.positive?

        return report.hung_up == :board ? 'closed' : 'silent'
      end
      case report.error
      when SocketError then 'dns_fail'
      when Errno::ECONNREFUSED then 'refused'
      else 'timeout'
      end
    end

    private

    # What +board+'s name resolves to; nothing for no board.
    def resolve(board) = board ? @resolver.call(board.host) : []

    def refusal(caller, board, face, now, ips)
      return Refusal.new(reason: :unknown, wait: nil) unless board
      return Refusal.new(reason: :not_petscii, wait: nil) if face == :petscii && !board.petscii?
      return Refusal.new(reason: :not_public, wait: nil) unless @callable.call(ips, board.port)

      limited(caller, ips.first, now)
    end

    # The Refusal of the limits: the caller's dials in the window, then the
    # lines to the address (two names of one machine share its lines).
    def limited(caller, ip, now)
      recent = recent(caller, now)
      return Refusal.new(reason: :rate, wait: (recent.first + @window - now).ceil) if recent.size >= @per_caller
      return Refusal.new(reason: :busy, wait: nil) if @lines[ip] >= @per_host

      nil
    end

    # The caller's dial times in the window; a caller without one is forgotten.
    def recent(caller, now)
      recent = @dials.fetch(caller, []).select { |t| t > now - @window }
      recent.empty? ? @dials.delete(caller) : @dials[caller] = recent
      recent
    end

    # Counts a dial of +caller+ to +ip+ at +now+; nil, for no Refusal.
    def take(caller, ip, now)
      @dials[caller] << now
      @lines[ip] += 1
      nil
    end

    # Frees the line of +call+ and records its outcome.
    def hang_up(call)
      call.ended_at = @clock.call
      @mutex.synchronize do
        @lines[call.ip] -= 1
        @lines.delete(call.ip) unless @lines[call.ip].positive?
      end
      write_live
      record(call)
    end

    # Records +refusal+ (when there is one) and returns it.
    def refused(refusal, board, face, now)
      return refusal unless refusal && @history

      @history.refused(at: now, reason: refusal.reason, board_id: board&.id, face: DialService.face(face))
      refusal
    rescue StandardError => e
      @log.call("ttg-gate-bbs: recording a refused dial: #{e.class}: #{e.message}")
      refusal
    end

    def record(call)
      return unless call.report

      result = probe_result(call)
      @recorder.record(call.board.id, result, kind: 'dial')
      @history&.dialled(at: call.ended_at || call.at, board_id: call.board.id, face: DialService.face(call.face),
                        result: result.result, seconds: call.seconds, bytes: call.report.received)
      @log.call("ttg-gate-bbs: dial #{call.board.address} #{result.result}")
    rescue StandardError => e
      @log.call("ttg-gate-bbs: recording the dial of #{call.board.address}: #{e.class}: #{e.message}")
    end

    # The dial of +call+ as a probe of its board.
    def probe_result(call)
      report = call.report
      ProbeResultModel.new(result: DialService.result(report), at: call.at,
                           latency_ms: report.connect_seconds && (report.connect_seconds * 1000).round,
                           ip: report.address)
    end

    # What the live file says: the dials in progress, the limits, the lines
    # to the busiest address, and the dial times in the window of each
    # caller (a list of lists: no caller is named).
    def live_state
      now = @clock.call
      @mutex.synchronize do
        windows = @dials.keys.map { |caller| recent(caller, now) }.reject(&:empty?)
        { 'live' => @lines.values.sum, 'at' => now.to_i, 'limits' => limits,
          'host_lines_max' => @lines.values.max.to_i, 'caller_dials' => windows.map { |times| times.map(&:to_i) } }
      end
    end

    def limits = { 'window_seconds' => @window, 'per_caller' => @per_caller, 'per_host' => @per_host }

    def write_live
      return unless @live_path

      @file.synchronize do
        FileUtils.mkdir_p(File.dirname(@live_path))
        tmp = "#{@live_path}.tmp"
        File.write(tmp, JSON.generate(live_state))
        File.rename(tmp, @live_path)
      end
    rescue SystemCallError => e
      @log.call("ttg-gate-bbs: #{@live_path}: #{e.message}")
    end
  end
end
