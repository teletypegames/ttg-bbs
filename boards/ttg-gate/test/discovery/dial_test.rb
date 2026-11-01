# frozen_string_literal: true

require_relative 'test_helper'

module Discovery
  class DialTest < Minitest::Test
    include TestHelper

    Report = Struct.new(:connected, :error, :address, :connect_seconds, :received, :hung_up, keyword_init: true)

    class Recorder
      attr_reader :records

      def initialize = @records = []
      def record(id, result, kind:) = @records << [id, result.result, kind, result.latency_ms, result.ip]
    end

    def setup
      database
      @now = 1_000.0
      @recorder = Recorder.new
      @live = File.join(@tmp, 'gate-dials.json')
      @dials = DialService.new(recorder: @recorder, live_path: @live, clock: -> { @now }, log: ->(_) {})
    end

    def board(host = 'bbs.example.org', state: 'online', tags: %w[ansi online])
      ListingModel.new(id: 7, host: host, port: 23, name: 'Example', state: state, software: nil, country: nil,
                       last_success_at: nil, first_probe_at: nil, first_seen_at: 0, state_since: nil, tags: tags,
                       optout: nil)
    end

    def dial(caller = '203.0.113.5', board = self.board, face: :modern, report: Report.new(connected: true, received: 9))
      @dials.dial(caller, board, face: face) { |call| call.report = report }
    end

    def test_ten_dials_in_ten_minutes_a_caller
      10.times { assert_kind_of DialService::Call, dial }
      refusal = dial
      assert_equal [:rate, 600], [refusal.reason, refusal.wait]
      assert_kind_of DialService::Call, dial('198.51.100.9')
      @now += 300
      assert_equal 300, dial.wait
      @now += 301
      assert_kind_of DialService::Call, dial
      assert_equal 12, @recorder.records.size
    end

    def test_three_lines_to_a_host_at_once
      inner = nil
      @dials.dial('a', board, face: :modern) do
        @dials.dial('b', board, face: :modern) do
          @dials.dial('c', board, face: :modern) do
            assert_equal 3, JSON.parse(File.read(@live))['live']
            inner = @dials.dial('d', board, face: :modern) { flunk 'a fourth line' }
            assert_kind_of DialService::Call, @dials.dial('d', board('other.example.org'), face: :modern) { nil }
          end
        end
      end
      assert_equal :busy, inner.reason
      assert_equal 0, @dials.live
      assert_equal 0, JSON.parse(File.read(@live))['live']
    end

    def test_the_line_is_freed_and_recorded_when_the_caller_hangs_up
      assert_raises(IOError) do
        @dials.dial('a', board, face: :modern) do |call|
          call.report = Report.new(connected: true, received: 0, hung_up: :caller)
          raise IOError
        end
      end
      assert_equal 0, @dials.live
      assert_equal [[7, 'silent', 'dial', nil, nil]], @recorder.records
    end

    def test_the_c64_dials_petscii_boards_only_and_warnings
      assert_equal :not_petscii, dial(face: :petscii).reason
      assert_kind_of DialService::Call, dial('a', board(tags: %w[petscii]), face: :petscii)
      assert_equal :unknown, @dials.check('a', nil, face: :modern).reason
      assert_equal [:petscii_only], @dials.warnings(board(tags: %w[petscii]), face: :modern)
      assert_empty @dials.warnings(board(tags: %w[petscii]), face: :petscii)
      assert_empty @dials.warnings(board(tags: %w[petscii ansi]), face: :modern)
      assert_equal [:dead], @dials.warnings(board(state: 'dead'), face: :petscii)
    end

    def test_results_of_a_report
      assert_equal 'ok', DialService.result(Report.new(connected: true, received: 3, hung_up: :board))
      assert_equal 'closed', DialService.result(Report.new(connected: true, received: 0, hung_up: :board))
      assert_equal 'silent', DialService.result(Report.new(connected: true, received: 0, hung_up: :caller))
      assert_equal 'dns_fail', DialService.result(Report.new(connected: false, error: SocketError.new))
      assert_equal 'refused', DialService.result(Report.new(connected: false, error: Errno::ECONNREFUSED.new))
      assert_equal 'timeout', DialService.result(Report.new(connected: false, error: Errno::ETIMEDOUT.new))
      dial(report: Report.new(connected: true, received: 5, connect_seconds: 0.0424, address: '192.0.2.1'))
      assert_equal [7, 'ok', 'dial', 42, '192.0.2.1'], @recorder.records.last
    end

    def test_a_caller_is_its_address_and_a_local_line_its_session
      assert_equal '203.0.113.5', DialService.caller_key('203.0.113.5', 'abc')
      assert_equal '203.0.113.5', DialService.caller_key('::ffff:203.0.113.5', 'abc')
      assert_equal 'line:abc', DialService.caller_key('172.17.0.1', 'abc')
      assert_equal 'line:abc', DialService.caller_key('127.0.0.1', 'abc')
      assert_equal 'line:abc', DialService.caller_key(nil, 'abc')
    end

    def test_the_metrics_read_the_live_dials
      catalog = CatalogRepository.new(@db)
      probes = ProbeRepository.new(@db)
      id = catalog.board_id('bbs.example.org', 23, 1)
      probes.add(id, probe('refused', at: 5_000), kind: 'dial', banner_hash: nil)
      File.write(@live, '{"live":2,"at":1}')
      text = MetricsService.new(File.join(@tmp, 'm.prom'), catalog: catalog, probes: probes, dials_path: @live).text(5_100)
      assert_includes text, "ttg_gate_bbs_discovery_dials_live 2\n"
      assert_includes text, %(ttg_gate_bbs_discovery_dials_last_hour{result="refused"} 1\n)
    end

    def test_the_metrics_of_the_prober
      catalog = CatalogRepository.new(@db)
      probes = ProbeRepository.new(@db)
      ids = %w[a b c].map { |h| catalog.board_id("#{h}.example.org", 23, 1) }
      result = ProbeResultModel.new(result: 'ok', at: 5_000, latency_ms: 10, ip: '192.0.2.1', banner: 'x' * 40,
                                    duration_ms: 1500)
      probes.add(ids[0], result, kind: 'scheduled', banner_hash: 'h')
      probes.save_state(ids[0], state: 'online', next_probe_at: 9_000)
      probes.save_state(ids[1], state: 'online', next_probe_at: 4_000)
      catalog.replace_tags(ids[0], %w[ansi cc:hu sw:synchronet net:fidonet])
      catalog.replace_tags(ids[1], %w[sw:ftn-mailer cc:us])
      optout = File.join(@tmp, 'optout.yml')
      File.write(optout, "hide: [x.example.org, 192.0.2.9]\nno_preview: []\n")
      text = MetricsService.new(File.join(@tmp, 'm.prom'), catalog: catalog, probes: probes, db_path: @db.path,
                                                            optout: OptoutRepository.new(optout))
                           .text(5_100, in_flight: 3)
      ['probes_in_flight 3', 'probes_due 2', 'next_probe_due_seconds 0',
       'probes_total{result="ok",kind="scheduled"} 1', 'probe_duration_seconds_avg_last_hour{result="ok"} 1.5',
       'probe_duration_seconds_max_last_hour 1.5', 'banner_bytes_avg_last_hour 40.0',
       'boards_by_encoding{encoding="ansi"} 1', 'boards_by_encoding{encoding="unknown"} 1',
       'boards_by_network{network="fidonet"} 1', 'boards_by_country{country="hu"} 1',
       'boards_by_software{software="synchronet"} 1', 'boards_by_software{software="ftn-mailer"} 1',
       'boards_by_software{software="other"} 0', 'optout_hosts{level="hide"} 2'].each do |line|
        assert_includes text, "ttg_gate_bbs_discovery_#{line}\n"
      end
      assert_match(/ttg_gate_bbs_discovery_db_bytes [1-9]/, text)
    end

    def test_banner_preview_keeps_what_draws
      text = BannerPreview.ansi("\e]0;title\a\e[2J\e[1;31mHi\xB0\r\n\e[?25l\e[6nThere\e[2Jsecond".b)
      assert_equal "\e[2J\e[1;31mHi░\r\nThere", text
      assert_equal "\x93\x05HI\r".b, BannerPreview.petscii("\x93\x05HI\r\x93NEXT".b)
      assert_equal 24, BannerPreview.ansi("x\n" * 40).count("\n")
    end
  end
end
