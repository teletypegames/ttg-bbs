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
  #   the Gate is no open telnet relay;
  # - at most +per_caller+ dials in +window+ seconds a caller, and at most
  #   +per_host+ connections at once from the Gate to one host (PER_CALLER,
  #   WINDOW and PER_HOST by default; Root reads them from the environment);
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
    # Seconds to wait for a board to accept the call: as long as a probe.
    CONNECT_TIMEOUT = TelnetProbe::CONNECT_TIMEOUT

    # Why a dial is refused: +rate+ (the caller dialled PER_CALLER times in
    # WINDOW; +wait+ seconds until the next one), +busy+ (PER_HOST lines to
    # the host are taken), +not_petscii+ (a C64 caller, a board without
    # PETSCII) or +unknown+ (no such board in the catalog).
    Refusal = Data.define(:reason, :wait)

    # One dial in progress: the caller's line hands the gateway's report to
    # it (BBS::Gateway::Report: connected, error, address, connect_seconds,
    # received, hung_up).
    class Call
      attr_accessor :report, :ended_at
      attr_reader :board, :at, :face

      def initialize(board, at, face = :modern)
        @board = board
        @at    = at
        @face  = face
      end

      # The seconds the line was connected to the board, whole.
      def seconds
        return 0 unless report&.connected && ended_at

        [(ended_at - at - report.connect_seconds.to_f).round, 0].max
      end
    end

    # The face a record names: modern or c64.
    def self.face(face) = face.to_s == 'petscii' ? 'c64' : face.to_s

    attr_reader :window, :per_caller, :per_host

    # [recorder]  ProberService (anything with #record(id, result, kind:))
    # [history]   DialRepository, or nil
    # [live_path] the JSON file of the live dials, or nil
    def initialize(recorder:, history: nil, live_path: nil, window: WINDOW, per_caller: PER_CALLER, per_host: PER_HOST,
                   clock: -> { Time.now.to_f }, log: ->(line) { warn line })
      @recorder   = recorder
      @history    = history
      @live_path  = live_path
      @window     = window
      @per_caller = per_caller
      @per_host   = per_host
      @clock     = clock
      @log       = log
      @mutex     = Mutex.new
      @file      = Mutex.new
      @dials     = Hash.new { |h, k| h[k] = [] }
      @lines     = Hash.new(0)
      write_live
    end

    # The key a caller is counted by: its IP address; a line from a private
    # or local address (bbsweb on the same host carries all its callers from
    # one) counts by its session.
    def self.caller_key(ip, session_id)
      addr = IPAddr.new(ip.to_s)
      return "line:#{session_id}" if addr.private? || addr.loopback? || addr.link_local?

      addr.ipv4_mapped? ? addr.native.to_s : addr.to_s
    rescue IPAddr::Error
      "line:#{session_id}"
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
      refused(@mutex.synchronize { refusal(caller, board, face, now) }, board, face, now)
    end

    # Dials +board+ for +caller+: when the rules let it, counts the dial,
    # yields a Call (the block puts the gateway's report on it), records the
    # outcome and returns the Call; else returns the Refusal and yields
    # nothing. The lines are freed and the outcome recorded also when the
    # caller hangs up inside (the IOError goes on).
    def dial(caller, board, face:)
      now = @clock.call
      refusal = @mutex.synchronize do
        refusal(caller, board, face, now).tap do |r|
          unless r
            @dials[caller] << now
            @lines[board.host] += 1
          end
        end
      end
      return refused(refusal, board, face, now) if refusal

      write_live
      call = Call.new(board, now.to_i, face)
      begin
        yield call
        call
      ensure
        call.ended_at = @clock.call
        @mutex.synchronize do
          @lines[board.host] -= 1
          @lines.delete(board.host) unless @lines[board.host].positive?
        end
        write_live
        record(call)
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

    def refusal(caller, board, face, now)
      return Refusal.new(reason: :unknown, wait: nil) unless board
      return Refusal.new(reason: :not_petscii, wait: nil) if face == :petscii && !board.petscii?

      recent = @dials[caller].select! { |t| t > now - @window } || @dials[caller]
      @dials.delete(caller) if recent.empty?
      return Refusal.new(reason: :rate, wait: (recent.first + @window - now).ceil) if recent.size >= @per_caller
      return Refusal.new(reason: :busy, wait: nil) if @lines[board.host] >= @per_host

      nil
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

      report = call.report
      result = ProbeResultModel.new(result: DialService.result(report), at: call.at,
                                    latency_ms: report.connect_seconds && (report.connect_seconds * 1000).round,
                                    ip: report.address)
      @recorder.record(call.board.id, result, kind: 'dial')
      @history&.dialled(at: call.ended_at || call.at, board_id: call.board.id, face: DialService.face(call.face),
                        result: result.result, seconds: call.seconds, bytes: report.received)
      @log.call("ttg-gate-bbs: dial #{call.board.address} #{result.result}")
    rescue StandardError => e
      @log.call("ttg-gate-bbs: recording the dial of #{call.board.address}: #{e.class}: #{e.message}")
    end

    # What the live file says: the dials in progress, the limits, the lines
    # to the busiest host, and the dial times in the window of each caller
    # (a list of lists: no caller is named).
    def live_state
      now = @clock.call
      @mutex.synchronize do
        windows = @dials.transform_values { |times| times.select { |t| t > now - @window } }
        windows.each { |caller, times| times.empty? ? @dials.delete(caller) : @dials[caller] = times }
        { 'live' => @lines.values.sum, 'at' => now.to_i,
          'limits' => { 'window_seconds' => @window, 'per_caller' => @per_caller, 'per_host' => @per_host },
          'host_lines_max' => @lines.values.max.to_i,
          'caller_dials' => windows.values.reject(&:empty?).map { |times| times.map(&:to_i) } }
      end
    end

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
