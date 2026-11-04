# frozen_string_literal: true

require_relative 'test_helper'

module Discovery
  class ImportTest < Minitest::Test
    include TestHelper

    # A ConfigRepository of the real signature and source-map files with the
    # sources of a test.
    class Config < ConfigRepository
      def initialize(sources, priority)
        super(TestHelper::CONFIG)
        @sources  = sources.freeze
        @priority = priority.freeze
      end
    end

    # Serves the bytes a test puts in.
    class Fetcher
      attr_accessor :bodies

      def initialize(bodies) = @bodies = bodies

      def fetch(source) = @bodies.fetch(source.id) { raise SourceFetcher::FetchError, "#{source.id}: down" }
    end

    def setup
      database
      @nodelist = source('fido', format: 'nodelist', network: 'fidonet')
      @sbl      = source('sbl', format: 'sbl_html')
      @syncterm = source('syncterm', format: 'syncterm_lst')
      @config   = Config.new([@nodelist, @sbl, @syncterm], %w[fido sbl syncterm])
      @alerts   = []
      @fetcher  = Fetcher.new(
        'fido'     => fixture('nodelist.txt'),
        'sbl'      => fixture('sbl.html'),
        'syncterm' => fixture('syncterm.lst')
      )
      optout = File.join(@tmp, 'optout.yml')
      File.write(optout, "hide: [three.example.org]\nno_preview: [192.0.2.99]\n")
      @import = ImportService.new(
        config:  @config,
        fetcher: @fetcher,
        tags:    TagService.new(@config),
        aliases: AliasService.new,
        optout:  OptoutRepository.new(optout),
        alert:   ->(m) { @alerts << m }
      )
    end

    def board(host, port) = BoardModel.where(host: host, port: port).naked.first

    def test_same_host_and_port_is_one_board
      outcomes = @import.call(now: 1_000)
      assert_equal [8, 3, 4], outcomes.map(&:records)
      assert_equal 1, BoardModel.where(host: 'one.example.org', port: 23).count
      one = board('one.example.org', 23)
      assert_equal %w[sbl syncterm], BoardSourceModel.of(one[:id]).map { |r| r[:source_id] }.sort
      assert_equal 8 + 2 + 1 + 2, BoardModel.count
    end

    def test_priority_decides_and_the_other_value_stays
      @import.call(now: 1_000)
      one = board('one.example.org', 23)
      assert_equal 'Example & One', one[:name]
      assert_equal(
        {
          'name'        => 'sbl',
          'sysop'       => 'sbl',
          'location'    => 'sbl',
          'software'    => 'sbl',
          'since'       => 'sbl',
          'ftn_address' => 'sbl'
        },
        JSON.parse(one[:provenance])
      )
      fields = BoardSourceModel.of(one[:id]).find { |r| r[:source_id] == 'syncterm' }[:fields]
      assert_equal 'Example One', fields['name']

      @config = Config.new([@nodelist, @sbl, @syncterm], %w[syncterm fido sbl])
      @import.instance_variable_set(:@config, @config)
      @import.call(now: 2_000)
      one = board('one.example.org', 23)
      assert_equal 'Example One', one[:name]
      assert_equal 'Ann Sysop, Bob Cosysop', one[:sysop]
      assert_equal 'syncterm', JSON.parse(one[:provenance])['name']
    end

    def test_a_board_out_of_every_source_is_delisted
      @import.call(now: 1_000)
      @fetcher.bodies['syncterm'] = fixture('syncterm.lst').sub('two.example.org:6502', 'four.example.org:6502')
      @import.call(now: 2_000)
      two = board('two.example.org', 6502)
      assert_equal 1, two[:delisted]
      assert_equal 2_000, two[:delisted_at]
      assert_equal 'Port In Address', two[:name]
      assert_equal 0, board('four.example.org', 6502)[:delisted]

      @fetcher.bodies['syncterm'] = fixture('syncterm.lst')
      @import.call(now: 3_000)
      assert_equal 0, board('two.example.org', 6502)[:delisted]
      assert_nil board('two.example.org', 6502)[:delisted_at]
    end

    def test_losing_more_than_half_is_refused
      @import.call(now: 1_000)
      @fetcher.bodies['fido'] = fixture('nodelist.txt').lines.reject { |l| l.include?('ITN') && !l.match?(/plain|Zone/) }.join
      outcome = @import.call(now: 2_000).find { |o| o.source == 'fido' }
      assert_equal :refused, outcome.status
      assert_equal 1, @alerts.size
      assert_match(/Fido: the parse gave 2 records against 8/, @alerts.first)
      assert_equal 8, BoardSourceModel.where(source_id: 'fido', active: 1).count
      assert_equal 8, SourceModel['fido'][:record_count]
      assert_equal 0, board('port.example.org', 2323)[:delisted]
    end

    def test_a_source_that_cannot_be_fetched_keeps_its_records
      @import.call(now: 1_000)
      @fetcher.bodies.delete('sbl')
      outcome = @import.call(now: 2_000).find { |o| o.source == 'sbl' }
      assert_equal :failed, outcome.status
      assert_equal 0, board('bare.example.org', 2323)[:delisted]
      assert_match(/sbl: down/, SourceModel['sbl'][:last_error])
    end

    def test_a_source_switched_off_no_longer_lists
      @import.call(now: 1_000)
      @import.instance_variable_set(:@config, Config.new([@nodelist, @sbl], %w[fido sbl]))
      @import.call(now: 2_000)
      assert_equal 1, board('two.example.org', 6502)[:delisted]
      assert_equal 0, board('one.example.org', 23)[:delisted]
    end

    def test_same_ip_and_port_are_aliases
      @import.call(now: 1_000)
      one  = board('one.example.org', 23)
      zone = board('zone1.example.org', 23)
      plain = board('plain.example.org', 23)
      [one, zone, plain].each { |b| BoardStateModel.save(b[:id], ip: '192.0.2.7') }
      assert_equal 2, AliasService.new.rebuild
      assert_nil board('one.example.org', 23)[:alias_of]
      assert_equal one[:id], board('zone1.example.org', 23)[:alias_of]
      assert_equal one[:id], board('plain.example.org', 23)[:alias_of]

      BoardStateModel.save(one[:id], ip: '192.0.2.8')
      AliasService.new.rebuild
      assert_nil board('one.example.org', 23)[:alias_of]
      assert_nil board('plain.example.org', 23)[:alias_of]
      assert_equal plain[:id], board('zone1.example.org', 23)[:alias_of]
    end

    def test_names_never_merge
      @import.call(now: 1_000)
      assert_equal 2, BoardModel.where(name: 'Example & One').count
    end

    def test_optout
      @import.call(now: 1_000)
      assert_equal 'hide', board('three.example.org', 23)[:optout]
      bare = board('bare.example.org', 2323)
      BoardStateModel.save(bare[:id], ip: '192.0.2.99')
      @import.call(now: 2_000)
      assert_equal 'no_preview', board('bare.example.org', 2323)[:optout]
      refute_includes BoardStateModel.due(3_000, limit: 100).map { |r| r[:host] }, 'three.example.org'
    end

    def test_tags_and_search
      @import.call(now: 1_000)
      one = board('one.example.org', 23)
      tags = TagModel.of(one[:id])
      assert_includes tags, 'src:sbl'
      assert_includes tags, 'src:syncterm'
      assert_includes tags, 'net:fidonet'
      assert_includes tags, 'net:dovenet'
      assert_includes tags, 'sw:synchronet'
      assert_includes tags, 'veteran'
      refute_includes tags, 'new'
      claimed = TagModel.of(board('one.example.org', 64)[:id])
      assert_includes claimed, 'claims:petscii'
      refute_includes claimed, 'petscii'
      assert_includes TagModel.of(board('plain.example.org', 23)[:id]), 'net:fidonet'
      assert_includes BoardsFtsModel.search('springfield'), one[:id]
      assert_includes BoardsFtsModel.search('host:bare'), board('bare.example.org', 2323)[:id]
    end

    def test_a_board_found_later_is_new_for_two_weeks
      @import.call(now: 1_000_000)
      @fetcher.bodies['syncterm'] = "#{fixture('syncterm.lst')}\n[Late]\nConnectionType=telnet\nAddress=late.example.org\n"
      @import.call(now: 1_200_000)
      late = board('late.example.org', 23)
      assert_includes TagModel.of(late[:id]), 'new'
      TagService.new(@config).refresh(late[:id], now: 1_200_000 + (15 * 86_400))
      refute_includes TagModel.of(late[:id]), 'new'
    end
  end
end
