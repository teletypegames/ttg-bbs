# frozen_string_literal: true

require_relative 'test_helper'

module Discovery
  class ProberTest < Minitest::Test
    include TestHelper

    class Probe
      attr_reader :calls

      def initialize(results)
        @results = results
        @calls = Queue.new
      end

      def call(host, port, c64: false)
        @calls << "#{host}:#{port}#{' c64' if c64}"
        sleep 0.05
        @results.fetch(host) { ProbeResultModel.new(result: 'timeout', at: Time.now.to_i, ip: '192.0.2.50') }
      end
    end

    class Geoip
      def country(ip) = ip == '192.0.2.10' ? 'hu' : nil
      def refresh(_) = nil
    end

    def setup
      database
      now = Time.now.to_i
      MetaModel.store('started_at', now)
      @ids = %w[a.example.org b.example.org c.example.org].map { |h| BoardModel.id_for(h, 23, now) }
      BoardModel.id_for('a.example.org', 2323, now)
      optout = File.join(@tmp, 'optout.yml')
      File.write(optout, "hide: [c.example.org]\n")
      @optout = OptoutRepository.new(optout)
    end

    def prober(results = {}, **)
      @probe = Probe.new(results)
      ProberService.new(probe: @probe, tags: TagService.new(config),
                        aliases: AliasService.new, optout: @optout, geoip: Geoip.new, config: config,
                        log: ->(_) {}, **)
    end

    def test_record_an_ok_probe
      banner = "\e[0mSynchronet BBS for Linux Version 3.22\r\n"
      columns = prober.record(@ids[0], probe('ok', at: 1_000, banner: banner, options: ['DO TTYPE', 'WILL BINARY']))
      state = BoardStateModel.of(@ids[0])
      assert_equal 'online', state[:state]
      assert_equal 'ansi', state[:encoding]
      assert_equal 'synchronet', state[:software_id]
      assert_equal 'hu', state[:country]
      assert_equal banner.b, state[:banner]
      assert_in_delta 1_000 + 86_400, state[:next_probe_at], 7200
      assert_equal 'online', columns[:state]
      assert_equal %w[ansi binary cc:hu online sw:synchronet ttype], TagModel.of(@ids[0])
      assert_equal banner.b, ProbeModel.where(board_id: @ids[0]).get(:banner)
    end

    def test_the_same_banner_is_stored_once
      p = prober
      p.record(@ids[0], probe('ok', at: 1_000, banner: 'Hello'))
      p.record(@ids[0], probe('ok', at: 2_000, banner: 'Hello'))
      p.record(@ids[0], probe('ok', at: 3_000, banner: 'Hello again'))
      assert_equal([1, 0, 1], ProbeModel.order(:at).select_map(:banner).map { |b| b.nil? ? 0 : 1 })
      assert_equal 3_000, BoardStateModel.of(@ids[0])[:banner_changed_at]
    end

    def test_failures_back_off_and_a_failed_dial_asks_for_a_probe
      p = prober
      p.record(@ids[1], probe('ok', at: 1_000))
      p.record(@ids[1], probe('timeout', at: 2_000))
      state = BoardStateModel.of(@ids[1])
      assert_equal ['flaky', 2_000 + 3600], [state[:state], state[:next_probe_at]]
      p.record(@ids[1], probe('refused', at: 3_000), kind: 'dial')
      state = BoardStateModel.of(@ids[1])
      assert_equal ['down', 3_000], [state[:state], state[:next_probe_at]]
      assert_equal 'dial', ProbeModel.reverse(:at).get(:kind)
      assert_equal 1_000, state[:last_success_at]
    end

    def test_a_dial_keeps_the_banner_options_and_schedule_of_the_probes
      p = prober
      p.record(@ids[0], probe('ok', at: 1_000, banner: "\e[0mSynchronet\r\n", options: ['DO TTYPE']))
      before = BoardStateModel.of(@ids[0])
      p.record(@ids[0], ProbeResultModel.new(result: 'ok', at: 2_000, latency_ms: 30, ip: '192.0.2.10'), kind: 'dial')
      state = BoardStateModel.of(@ids[0])
      assert_equal [before[:banner], before[:encoding], before[:options], before[:next_probe_at]],
                   [state[:banner], state[:encoding], state[:options], state[:next_probe_at]]
      assert_equal [2_000, 'online'], [state[:last_success_at], state[:state]]
      assert_includes TagModel.of(@ids[0]), 'ttype'
    end

    def test_run_calls_the_due_boards_once_a_host_and_skips_hidden_ones
      p = prober({ 'a.example.org' => probe('ok', at: Time.now.to_i, banner: 'x') }, concurrency: 8)
      p.run(limit: 3)
      calls = []
      calls << @probe.calls.pop until @probe.calls.empty?
      assert_equal 3, calls.size
      assert_equal %w[a.example.org:23 a.example.org:2323 b.example.org:23], calls.sort
      assert_empty(BoardStateModel.due(Time.now.to_i, limit: 10).reject { |r| r[:host] == 'c.example.org' })
      refute_includes calls, 'c.example.org:23'
    end
  end
end
