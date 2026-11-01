# frozen_string_literal: true

require_relative 'test_helper'

module Discovery
  class ParsersTest < Minitest::Test
    include TestHelper

    def nodelist = NodelistParser.parse(fixture('nodelist.txt'), source('fidonet', network: 'fidonet'))

    def test_nodelist_takes_the_itn_nodes
      keys = nodelist.map(&:key)
      assert_equal %w[zone1.example.org:23 plain.example.org:23 port.example.org:2323 bbs.example.org:23
                      full.example.org:6400 named.example.org:2300 cafe.example.org:23 region.example.org:23], keys
    end

    def test_nodelist_fields_and_addresses
      plain = nodelist.find { |r| r.host == 'plain.example.org' }
      assert_equal 'Plain ITN BBS', plain.name
      assert_equal 'Springfield IL', plain.location
      assert_equal 'Ann Sysop', plain.sysop
      assert_equal '1:100/1', plain.ftn_address
      assert_equal '1:1/0', nodelist.first.ftn_address
      assert_equal '2:24/10', nodelist.last.ftn_address
      assert_equal '1:100/7', nodelist.find { |r| r.host == 'named.example.org' }.ftn_address
    end

    def test_nodelist_leaves_out_down_and_mail_only_nodes
      hosts = nodelist.map(&:host)
      refute_includes hosts, 'down.example.org'
      refute_includes hosts, 'binkp.example.org'
      refute_includes hosts, 'net100.example.org'
    end

    def test_nodelist_reads_cp437
      assert_equal 'Café BBS', nodelist.find { |r| r.host == 'cafe.example.org' }.name
    end

    def test_nodelist_first_node_of_an_endpoint_wins
      assert_equal(1, nodelist.count { |r| r.key == 'plain.example.org:23' })
      assert_equal 'Plain ITN BBS', nodelist.find { |r| r.key == 'plain.example.org:23' }.name
    end

    def sbl = SblHtmlParser.parse(fixture('sbl.html'), source('sbl', format: 'sbl_html'))

    def test_sbl_takes_every_telnet_service
      assert_equal %w[one.example.org:23 one.example.org:64 bare.example.org:2323], sbl.map(&:key)
    end

    def test_sbl_fields
      one = sbl.first
      assert_equal 'Example & One', one.name
      assert_equal 1991, one.since
      assert_equal 'Ann Sysop, Bob Cosysop', one.sysop
      assert_equal 'Springfield, USA', one.location
      assert_equal 'Synchronet BBS for Linux Version 3.22', one.software
      assert_equal '1:100/1', one.ftn_address
      assert_equal({ 'comment' => 'Windows', 'networks' => %w[DOVE-Net FidoNet] }, one.hints)
      assert_equal 'PETSCII-40', sbl[1].hints['comment']
    end

    def test_sbl_bare_name_and_no_software
      bare = sbl.last
      assert_equal 'Bare Board', bare.name
      assert_equal 2022, bare.since
      assert_nil bare.software
      assert_equal ['fsxNet'], bare.hints['networks']
    end

    def syncterm = SynctermLstParser.parse(fixture('syncterm.lst'), source('syncterm', format: 'syncterm_lst'))

    def test_syncterm_takes_the_telnet_entries
      assert_equal %w[one.example.org:23 one.example.org:64 two.example.org:6502 three.example.org:23],
                   syncterm.map(&:key)
    end

    def test_syncterm_names_and_hints
      assert_equal ['Example One'], syncterm.first(2).map(&:name).uniq
      assert_equal({ 'service' => 'telnet', 'comment' => 'The main line' }, syncterm.first.hints)
      assert_equal({ 'screen_mode' => 'C64', 'service' => 'PETSCII-40' }, syncterm[1].hints)
      assert_equal 'Port In Address', syncterm[2].name
    end

    def cbbs = CbbsJsonParser.parse(fixture('cbbs.json'), source('cbbs', format: 'cbbs_json'))

    def test_cbbs_takes_the_telnet_addresses
      assert_equal %w[corner.example.org:6400 two.example.org:23 url.example.org:64128 bracket.example.org:23],
                   cbbs.map(&:key)
    end

    def test_cbbs_facts
      corner = cbbs.first
      assert_equal 'Commodore Corner', corner.name
      assert_equal 'Springfield, IL', corner.location
      assert_equal 'Image 1.2b', corner.software
      assert_equal 'C128, SD2IEC, SwiftLink', corner.hardware
      assert_equal 'http://corner.example.org', corner.website
      assert_equal({ 'platform' => 'Commodore', 'updated_at' => '2025-08-15 23:05:39' }, corner.hints)
      assert_nil cbbs[1].website
      assert_nil cbbs[1].location
      assert_equal 'url.example.org', cbbs[2].website
    end

    def test_cbbs_keeps_nothing_personal
      stored = JSON.generate(cbbs.map(&:stored_fields))
      ['ann@example.org', 'cy@example.org', 'annsysop', 'Ann Sysop', 'finest', 'img.example.org', 'Bob'].each do |personal|
        refute_includes stored, personal
      end
      assert(cbbs.all? { |r| r.sysop.nil? })
      refute_match(/online|isFavorite|flashterm|comment|image/, stored)
    end

    def test_cbbs_refuses_what_is_not_its_list
      assert_raises(ArgumentError) { CbbsJsonParser.parse('<html>', source('cbbs', format: 'cbbs_json')) }
      assert_raises(ArgumentError) { CbbsJsonParser.parse('{"a": 1}', source('cbbs', format: 'cbbs_json')) }
    end

    def test_parsers_by_format
      assert_equal CbbsJsonParser, Parsers.for('cbbs_json')
      assert_equal SblHtmlParser, Parsers.for('sbl_html')
      assert_raises(KeyError) { Parsers.for('gopher') }
    end

    def test_zip_member
      bytes = ZipReader.read(fixture('infopack.zip'), /\AEXAMPLE\.\d{3}\z/)
      assert_equal fixture('nodelist.txt'), bytes
      assert_nil ZipReader.read(fixture('infopack.zip'), /\ANOPE\z/)
      assert_raises(ArgumentError) { ZipReader.read('not a zip', /x/) }
    end

    def test_address_rules
      assert_equal 'bbs.example.org', Address.host(' BBS.Example.ORG. ')
      assert_equal '192.0.2.1', Address.host('192.0.2.1')
      assert_equal '2001:db8::1', Address.host('[2001:db8::1]')
      assert_nil Address.host('localhost')
      assert_nil Address.host('not a host')
      assert_nil Address.host('1.2.3')
      assert_nil Address.port('0')
      assert_nil Address.port('65536')
      assert_equal 23, Address.port('23')
    end
  end
end
