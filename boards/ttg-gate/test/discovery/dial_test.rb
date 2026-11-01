# frozen_string_literal: true

require_relative 'test_helper'
require 'minitest/mock'
require_relative '../../lib/ui/dial'

module Discovery
  class DialTest < Minitest::Test
    include TestHelper

    PUBLIC = '93.184.215.14'
    OTHER  = '93.184.215.15'
    # Each name of the tests and the address it resolves to.
    ADDRESSES = { 'bbs.example.org' => PUBLIC, 'alias.example.org' => PUBLIC, 'other.example.org' => OTHER }.freeze

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
      @history = DialRepository.new(@db)
      @dials = DialService.new(recorder: @recorder, history: @history, live_path: @live, clock: -> { @now }, log: ->(_) {},
                               resolver: ->(host) { [ADDRESSES.fetch(host)] })
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

    def test_two_names_of_one_address_share_its_lines
      @dials.dial('a', board, face: :modern) do
        @dials.dial('b', board('alias.example.org'), face: :modern) do
          @dials.dial('c', board, face: :modern) do
            assert_equal :busy, @dials.check('d', board('alias.example.org'), face: :modern).reason
            assert_nil @dials.check('d', board('other.example.org'), face: :modern)
          end
        end
      end
      assert_nil @dials.check('d', board('alias.example.org'), face: :modern)
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

    def test_the_c64_dials_petscii_and_ascii_boards_and_warnings
      assert_equal :not_petscii, dial(face: :petscii).reason
      assert_kind_of DialService::Call, dial('a', board(tags: %w[petscii]), face: :petscii)
      assert_kind_of DialService::Call, dial('b', board(tags: %w[ascii online]), face: :petscii)
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

    def test_a_board_inside_the_network_is_not_dialled
      dials = DialService.new(recorder: @recorder, history: @history, clock: -> { @now }, log: ->(_) {},
                              resolver: ->(_) { ['172.17.0.1'] })
      refusal = dials.dial('203.0.113.5', board, face: :modern) { flunk 'dialled' }
      assert_equal :not_public, refusal.reason
      assert_equal 1, @history.refusals_since(0)['not_public']
    end

    def test_the_line_goes_to_the_resolved_address
      call = dial
      assert_equal PUBLIC, call.ip
    end

    # A stand-in for BBS::Gateway that keeps what it was built with.
    class Gateway
      attr_reader :options

      def initialize(**options) = @options = options
      def call(_session) = yield(Report.new(connected: true, received: 1))
    end

    def test_a_catalog_dial_goes_to_the_address_and_ends_when_idle
      gateway = nil
      dials = DialService.new(recorder: @recorder, clock: -> { @now }, log: ->(_) {}, idle: 90,
                              resolver: ->(_) { [PUBLIC] })
      BBS::Gateway.stub(:new, ->(**options) { gateway = Gateway.new(**options) }) do
        UI.dial_catalog(Object.new, dials, 'a', board, face: :modern)
      end
      assert_equal [PUBLIC, 23, 90], gateway.options.values_at(:host, :port, :idle)
    end

    def test_only_an_ascii_board_without_petscii_is_translated_for_a_c64
      assert_predicate board(tags: %w[ascii]), :translated_for_c64?
      refute_predicate board(tags: %w[ascii petscii]), :translated_for_c64?
      refute_predicate board(tags: %w[ansi]), :c64?
      assert_predicate board(tags: %w[ascii]), :c64?
    end

    def test_a_caller_is_its_address_and_a_local_line_its_session
      assert_equal '203.0.113.5', DialService.caller_key('203.0.113.5', 'abc')
      assert_equal '203.0.113.5', DialService.caller_key('::ffff:203.0.113.5', 'abc')
      assert_equal 'line:abc', DialService.caller_key('172.17.0.1', 'abc')
      assert_equal 'line:abc', DialService.caller_key('127.0.0.1', 'abc')
      assert_equal 'line:abc', DialService.caller_key(nil, 'abc')
      assert_equal 'line:abc', DialService.caller_key('fd00::1', 'abc')
    end

    def test_an_ipv6_caller_is_its_whole_prefix
      first = DialService.caller_key('2a01:4f8:1:2:aaaa::1', 'abc')
      assert_equal '2a01:4f8:1:2::/64', first
      assert_equal first, DialService.caller_key('2a01:4f8:1:2:ffff:ffff:ffff:ffff', 'xyz')
      refute_equal first, DialService.caller_key('2a01:4f8:1:3::1', 'abc')
      10.times { |i| assert_kind_of DialService::Call, dial(DialService.caller_key("2a01:4f8:1:2::#{i + 1}", 's')) }
      assert_equal :rate, dial(DialService.caller_key('2a01:4f8:1:2::beef', 's')).reason
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

    def test_the_limits_come_from_the_environment
      env = { 'TTG_GATE_BBS_DATA' => @tmp, 'TTG_GATE_BBS_DISCOVERY_DB' => File.join(@tmp, 'root.sqlite3'),
              'TTG_GATE_BBS_DIAL_WINDOW' => '300', 'TTG_GATE_BBS_DIAL_PER_CALLER' => '4', 'TTG_GATE_BBS_DIAL_PER_HOST' => '2',
              'TTG_GATE_BBS_DIAL_IDLE' => '120' }
      root = Root.new(env)
      assert_equal({ window: 300, per_caller: 4, per_host: 2, idle: 120 }, root.dial_limits)
      dials = root.dials(log: ->(_) {})
      assert_equal [300, 4, 2, 120], [dials.window, dials.per_caller, dials.per_host, dials.idle]
      assert_equal({ 'window_seconds' => 300, 'per_caller' => 4, 'per_host' => 2 },
                   JSON.parse(File.read(root.dials_path))['limits'])
      root.db.close
      _, err = capture_io do
        bad = Root.new(env.merge('TTG_GATE_BBS_DIAL_WINDOW' => 'soon', 'TTG_GATE_BBS_DIAL_PER_HOST' => '0'))
        assert_equal({ window: 600, per_caller: 4, per_host: 3, idle: 120 }, bad.dial_limits)
        bad.db.close
      end
      assert_includes err, 'TTG_GATE_BBS_DIAL_WINDOW=soon'
      assert_equal({ window: 600, per_caller: 10, per_host: 3, idle: 600 }, Root.new(env.slice('TTG_GATE_BBS_DATA')).dial_limits)
    end

    def test_the_limits_given_hold
      dials = DialService.new(recorder: @recorder, clock: -> { @now }, log: ->(_) {}, window: 60, per_caller: 2, per_host: 1,
                              resolver: ->(_) { [PUBLIC] })
      2.times { dials.dial('a', board, face: :modern) { |c| c.report = Report.new(connected: true, received: 1) } }
      assert_equal [:rate, 60], dials.check('a', board, face: :modern).deconstruct
      dials.dial('b', board, face: :modern) { assert_equal :busy, dials.check('c', board, face: :modern).reason }
    end

    def test_every_refusal_is_recorded_without_the_caller
      10.times { dial }
      assert_equal :rate, dial.reason
      assert_equal :rate, @dials.check('203.0.113.5', board(tags: %w[petscii]), face: :petscii).reason
      @dials.dial('a', board, face: :modern) do
        @dials.dial('c', board, face: :modern) do
          @dials.dial('d', board, face: :modern) do
            assert_equal :busy, @dials.dial('b', board, face: :modern) { nil }.reason
            assert_equal :busy, @dials.check('e', board(tags: %w[petscii]), face: :petscii).reason
          end
        end
      end
      assert_equal :not_petscii, @dials.check('a', board, face: :petscii).reason
      assert_equal :unknown, @dials.check('a', nil, face: :modern).reason
      assert_equal :unknown, @dials.check('a', nil, face: :petscii).reason
      rows = @db.query('SELECT * FROM dial_refusals ORDER BY id')
      assert_equal %w[id at reason board_id face], rows.first.keys
      assert_equal([%w[rate modern], %w[rate c64], %w[busy modern], %w[busy c64], %w[not_petscii c64], %w[unknown modern],
                    %w[unknown c64]], rows.map { |r| [r['reason'], r['face']] })
      assert_equal [7, nil], [rows.first['board_id'], rows.last['board_id']]
      refute(rows.any? { |r| r.values.any? { |v| v.to_s.include?('203.0.113') || %w[a b c d e].include?(v) } })
      totals = @history.refusal_totals
      assert_equal 1, totals[%w[rate c64]]
      assert_equal 0, totals[%w[not_petscii modern]]
      assert_equal 1, @history.refusals_since(0)['not_petscii']
    end

    def test_old_refusals_are_pruned_into_the_running_total
      @history.refused(at: 1_000, reason: :rate, board_id: 7, face: 'modern')
      @history.dialled(at: 1_000, board_id: 7, face: 'c64', result: 'ok', seconds: 5, bytes: 10)
      @history.prune(1_000 + DialRepository::KEEP + 1, force: true)
      assert_equal 0, @db.value('SELECT COUNT(*) FROM dial_refusals')
      assert_equal 0, @db.value('SELECT COUNT(*) FROM dials')
      @history.refused(at: 2_000_000_000, reason: :rate, board_id: 7, face: 'modern')
      assert_equal 2, @history.refusal_totals[%w[rate modern]]
    end

    def test_a_dial_records_its_time_and_bytes
      @dials.dial('a', board(tags: %w[petscii]), face: :petscii) do |call|
        @now += 30
        call.report = Report.new(connected: true, received: 4096, connect_seconds: 0.2)
      end
      row = @db.first('SELECT * FROM dials')
      assert_equal [7, 'c64', 'ok', 30, 4096, 1_030], row.values_at('board_id', 'face', 'result', 'seconds', 'bytes', 'at')
      @dials.dial('a', board, face: :modern) { |call| call.report = Report.new(connected: false, error: SocketError.new) }
      assert_equal [2, 30, 4096], @history.traffic_since(0)
    end

    def test_the_metrics_of_the_dial_limits
      catalog = CatalogRepository.new(@db)
      probes = ProbeRepository.new(@db)
      id = catalog.board_id('bbs.example.org', 23, 1)
      probes.add(id, probe('ok', at: 900), kind: 'dial', banner_hash: nil)
      9.times { dial }
      2.times { dial('198.51.100.9') }
      dial(report: Report.new(connected: true, received: 500, connect_seconds: 0.1))
      @dials.check('203.0.113.5', board, face: :modern)
      text = nil
      @dials.dial('x', board, face: :modern) do
        @dials.dial('y', board, face: :modern) do
          refute_includes File.read(@live), '203.0.113.5'
          text = MetricsService.new(File.join(@tmp, 'm.prom'), catalog: catalog, probes: probes, dials_path: @live,
                                                                history: @history).text(@now.to_i + 10)
        end
      end
      ['dial_limit{kind="window_seconds"} 600', 'dial_limit{kind="per_caller"} 10', 'dial_limit{kind="per_host"} 3',
       'dial_caller_max_in_window 10', 'dial_callers_at_limit 1', 'dial_host_lines_max 2',
       'dial_refusals_total{reason="rate",face="modern"} 1', 'dial_refusals_total{reason="busy",face="c64"} 0',
       'dial_refusals_last_hour{reason="rate"} 1', 'dial_refusals_last_hour{reason="unknown"} 0',
       'dial_bytes_last_hour 599', 'dials_total{result="ok"} 1'].each do |line|
        assert_includes text, "ttg_gate_bbs_discovery_#{line}\n"
      end
      assert_match(/dial_seconds_last_hour 0\n/, text)
      later = MetricsService.new(File.join(@tmp, 'm.prom'), catalog: catalog, probes: probes, dials_path: @live,
                                                             history: @history).text(@now.to_i + 601)
      assert_includes later, "ttg_gate_bbs_discovery_dial_caller_max_in_window 0\n"
    end

    def test_banner_preview_keeps_what_draws
      text = BannerPreview.ansi("\e]0;title\a\e[2J\e[1;31mHi\xB0\r\n\e[?25l\e[6nThere\e[2Jsecond".b)
      assert_equal "\e[2J\e[1;31mHi░\r\nThere", text
      assert_equal "\x93\x05HI\r".b, BannerPreview.petscii("\x93\x05HI\r\x93NEXT".b)
      assert_equal 24, BannerPreview.ansi("x\n" * 40).count("\n")
    end
  end
end
