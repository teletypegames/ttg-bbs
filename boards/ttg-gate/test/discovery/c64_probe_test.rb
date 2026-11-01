# frozen_string_literal: true

require_relative 'test_helper'
require 'socket'

module Discovery
  # The C64-style call: who gets one, what it sends, and the tags it gives.
  class C64ProbeTest < Minitest::Test
    include TestHelper

    N = TelnetNegotiator
    ANSI    = "\e[2J\e[1;33mWelcome, ANSI caller\r\n".b
    PETSCII = "\x93\x05\x0EWELCOME, COMMODORE\r".b

    class Geoip
      def country(_) = nil
      def refresh(_) = nil
    end

    def setup
      database
      @catalog = CatalogRepository.new(@db)
      @probes  = ProbeRepository.new(@db)
      @catalog.set_meta('started_at', 0)
      @servers = []
      @threads = []
    end

    def teardown
      @servers.each(&:close)
      @threads.each(&:kill)
      super
    end

    def bytes(*codes) = codes.flat_map { |c| c.is_a?(String) ? c.bytes : [c] }.pack('C*')

    def prober(probe = TelnetProbe.new(connect_timeout: 2, read_timeout: 1.2, nudge_after: 0.4))
      optout = File.join(@tmp, 'optout.yml')
      File.write(optout, "{}\n")
      ProberService.new(catalog: @catalog, probes: @probes, probe: probe, tags: TagService.new(@catalog, @probes, config),
                        aliases: AliasService.new(@catalog), optout: OptoutRepository.new(optout), geoip: Geoip.new,
                        config: config, c64_gap: 0, log: ->(_) {})
    end

    # A board on a local port that asks for the terminal type, and answers
    # +ansi+ when it gets ANSI, +petscii+ when the caller knows no telnet.
    # +calls+ gets "ansi" or "c64" a call.
    def board(ansi:, petscii:, calls: Queue.new)
      server = TCPServer.new('127.0.0.1', 0)
      @servers << server
      @threads << Thread.new do
        loop do
          client = server.accept
          Thread.new(client) { |c| converse(c, ansi, petscii, calls) }
        end
      rescue IOError, SystemCallError
        nil
      end
      server.addr[1]
    end

    def converse(client, ansi, petscii, calls)
      client.write(bytes(N::IAC, N::DO, N::TTYPE))
      answer = client.wait_readable(0.3) ? client.readpartial(64) : ''.b
      if answer.include?(bytes(N::IAC, N::WILL, N::TTYPE))
        client.write(bytes(N::IAC, N::SB, N::TTYPE, 1, N::IAC, N::SE))
        type = client.readpartial(64)
        calls << (type.include?('ANSI') ? 'ansi' : '?')
        client.write(ansi)
      else
        calls << (answer.include?(bytes(N::IAC, N::WONT, N::TTYPE)) ? 'c64' : 'silent')
        client.write(petscii)
      end
      sleep 1.5
    rescue IOError, SystemCallError
      nil
    ensure
      client.close
    end

    # A catalog board on +port+ of localhost, listed by the CBBS Outpost
    # when +claimed+.
    def catalog_board(port, claimed:)
      id = @catalog.board_id('127.0.0.1', port, 0)
      if claimed
        record = RecordModel.new(source_id: 'cbbs', host: '127.0.0.1', port: port, name: 'Corner',
                                 hints: { 'platform' => 'Commodore' })
        @catalog.apply('cbbs', [record], 0)
      end
      TagService.new(@catalog, @probes, config).refresh(id, now: 0)
      id
    end

    def test_the_c64_negotiator_refuses_every_option
      telnet = N.new(c64: true)
      _, reply = telnet.feed(bytes(N::IAC, N::DO, N::TTYPE, N::IAC, N::DO, N::NAWS, N::IAC, N::WILL, 1,
                                   N::IAC, N::SB, N::TTYPE, 1, N::IAC, N::SE))
      assert_equal bytes(N::IAC, N::WONT, N::TTYPE, N::IAC, N::WONT, N::NAWS, N::IAC, N::DONT, 1), reply
      assert_equal ['DO TTYPE', 'DO NAWS', 'WILL ECHO'], telnet.options
    end

    def test_a_board_of_two_faces_gets_both_tags_and_both_banners
      calls = Queue.new
      id = catalog_board(board(ansi: ANSI, petscii: PETSCII, calls: calls), claimed: true)
      prober.run(limit: 1)
      assert_equal %w[ansi c64], [calls.pop, calls.pop]
      tags = @catalog.tags(id)
      assert_includes tags, 'ansi'
      assert_includes tags, 'petscii'
      assert_includes tags, 'claims:petscii'
      state = @probes.state(id)
      assert_equal [ANSI, 'ansi', PETSCII, 'petscii'],
                   [state['banner'], state['encoding'], state['c64_banner'], state['c64_encoding']]
      assert_equal(%w[scheduled c64], @db.query('SELECT kind FROM probes ORDER BY id').map { |r| r['kind'] })
      page = BrowseService.new(DirectoryRepository.new(@db), config).page(id)
      assert_equal ANSI, page.banner
      assert_equal PETSCII, page.c64_banner
      assert_equal 'ansi, petscii to a C64', page.fields.find { |f| f.label == 'Encoding' }.value
      refute page.listing.petscii_only?
    end

    def test_an_ansi_only_board_claimed_by_a_source_is_no_petscii_board
      id = catalog_board(board(ansi: ANSI, petscii: ANSI), claimed: true)
      prober.run(limit: 1)
      tags = @catalog.tags(id)
      assert_includes tags, 'claims:petscii'
      assert_includes tags, 'ansi'
      refute_includes tags, 'petscii'
      assert_equal 'ansi', @probes.state(id)['c64_encoding']
      assert_empty BrowseService.new(DirectoryRepository.new(@db), config).search('', petscii: true)
    end

    def test_a_petscii_only_board_is_petscii_without_a_claim
      id = catalog_board(board(ansi: PETSCII, petscii: PETSCII), claimed: false)
      prober.run(limit: 1)
      assert_equal 2, @db.value('SELECT COUNT(*) FROM probes')
      tags = @catalog.tags(id)
      assert_includes tags, 'petscii'
      refute_includes tags, 'claims:petscii'
      assert BrowseService.new(DirectoryRepository.new(@db), config).search('', petscii: true).first.petscii_only?
    end

    def test_an_unclaimed_ansi_board_gets_no_c64_call
      id = catalog_board(board(ansi: ANSI, petscii: PETSCII), claimed: false)
      prober.run(limit: 1)
      assert_equal 1, @db.value('SELECT COUNT(*) FROM probes')
      refute_includes @catalog.tags(id), 'petscii'
    end

    # A probe that answers from a table: c64 => result.
    class Scripted
      attr_reader :calls

      def initialize(results)
        @results = results
        @calls = []
      end

      def call(host, port, c64: false)
        @calls << [host, port, c64]
        @results.fetch(c64)
      end
    end

    def test_no_c64_call_after_a_failed_one_and_c64_calls_leave_the_state_alone
      id = catalog_board(2364, claimed: true)
      now = Time.now.to_i
      script = Scripted.new(false => ProbeResultModel.new(result: 'timeout', at: now))
      prober(script).run(limit: 1)
      assert_equal [['127.0.0.1', 2364, false]], script.calls
      assert_nil @probes.state(id)['c64_probe_at']

      other = catalog_board(2366, claimed: true)
      p = prober
      p.record(other, probe('ok', at: now - 10, banner: ANSI))
      p.record_c64(other, probe('timeout', at: now - 5))
      p.record_c64(other, probe('refused', at: now - 4))
      state = @probes.state(other)
      assert_equal %w[online ok refused], [state['state'], state['last_result'], state['c64_result']]
      assert_equal 1.0, state['success_rate_7d']
    end

    def test_a_claimed_board_answering_before_the_c64_call_gets_its_first_one_alone
      id = catalog_board(2364, claimed: true)
      other = catalog_board(2365, claimed: false)
      now = Time.now.to_i
      [id, other].each { |b| prober.record(b, probe('ok', at: now - 60, banner: ANSI)) }
      due = @probes.due(now, limit: 10)
      assert_equal([[id, 1]], due.map { |r| [r['id'], r['c64_only']] })

      script = Scripted.new(true => probe('ok', at: now, banner: PETSCII))
      prober(script).run(limit: 1)
      assert_equal [['127.0.0.1', 2364, true]], script.calls
      assert_equal 'petscii', @probes.state(id)['c64_encoding']
      assert_includes @catalog.tags(id), 'petscii'
      assert_empty @probes.due(now, limit: 10)
    end

    def test_tagging_rules
      tags = TagService.new(@catalog, @probes, config)
      board = { 'first_seen_at' => 0, 'since' => nil, 'software' => nil }
      claim = [{ 'source_id' => 'syncterm', 'fields' => { 'screen_mode' => 'C64' } }]
      assert_equal %w[claims:petscii src:syncterm], tags.tags(board, claim, nil, 0)
      assert_equal %w[ansi claims:petscii src:syncterm],
                   tags.tags(board, claim, { 'encoding' => 'ansi', 'c64_encoding' => 'ansi' }, 0)
      assert_equal %w[ansi claims:petscii petscii src:syncterm],
                   tags.tags(board, claim, { 'encoding' => 'ansi', 'c64_encoding' => 'petscii' }, 0)
      assert_equal %w[petscii], tags.tags(board, [], { 'encoding' => 'petscii', 'c64_encoding' => 'unknown' }, 0)
      assert_equal %w[claims:petscii], SearchQuery.parse('claims:petscii').tags
    end

    def test_the_metrics_count_the_c64_calls
      id = catalog_board(2364, claimed: true)
      prober.record_c64(id, probe('ok', at: Time.now.to_i, banner: PETSCII))
      text = MetricsService.new(File.join(@tmp, 'm.prom'), catalog: @catalog, probes: @probes).text(Time.now.to_i)
      assert_includes text, 'ttg_gate_bbs_discovery_probes_total{result="ok",kind="c64"} 1'
    end
  end
end
