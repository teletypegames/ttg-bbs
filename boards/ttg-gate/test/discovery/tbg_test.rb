# frozen_string_literal: true

require_relative 'test_helper'

module Discovery
  class TbgTest < Minitest::Test
    include TestHelper

    def tbg(bytes = fixture('tbg.zip')) = TbgZipParser.parse(bytes, source('tbg', format: 'tbg_zip'))

    def test_takes_the_telnet_entries_only
      assert_equal %w[corner.example.org:6400 plain.example.org:23 amiga.example.org:6800], tbg.map(&:key)
    end

    def test_facts
      corner, plain, amiga = tbg
      assert_equal 'Commodore Corner', corner.name
      assert_equal 'Springfield, USA', corner.location
      assert_equal 'Image BBS', corner.software
      assert_equal 'corner.example.org', corner.website
      assert_equal({ 'updated_at' => 'March 22, 2025', 'mentions' => ['PETSCII'] }, corner.hints)
      assert_equal 'Plain ANSI & Co', plain.name
      assert_equal 'S&T', plain.software
      assert_equal({ 'updated_at' => 'October 7, 2026' }, plain.hints)
      assert_equal 'AMIGA C-NET', amiga.name
      assert_nil amiga.location
      assert_nil amiga.website
    end

    def test_the_full_listing_alone_has_the_names_of_the_list
      full = ZipReader.read(fixture('tbg.zip'), TbgZipParser::FULL)
      assert_equal ['COMMODORE CORNER', 'PLAIN ANSI BOARD', 'AMIGA C-NET'], tbg(full).map(&:name)
    end

    def test_keeps_nothing_personal
      stored = JSON.generate(tbg.map(&:stored_fields))
      ['ann@example.org', 'cy@example.org', 'Ann Sysop', 'Cy Sysop', 'C128', 'Doors', 'header.example.org'].each do |personal|
        refute_includes stored, personal
      end
      assert(tbg.all? { |r| r.sysop.nil? })
    end

    def test_refuses_what_is_not_its_list
      assert_raises(ArgumentError) { tbg('<html>no boards</html>') }
      assert_raises(ArgumentError) { tbg(fixture('infopack.zip')) }
    end

    def test_a_petscii_claim_from_the_description_or_a_commodore_program
      database
      MetaModel.store('started_at', 0)
      tags = TagService.new(config)
      board = { first_seen_at: 0, since: nil, software: nil }
      claims = tbg.map { |r| tags.tags(board, [{ source_id: 'tbg', fields: r.stored_fields }], nil, 0) }
      assert_equal [%w[claims:petscii src:tbg], %w[src:tbg], %w[src:tbg]], claims
      color64 = [{ source_id: 'tbg', fields: { 'software' => 'Color 64' } }]
      assert_includes tags.tags(board, color64, nil, 0), 'claims:petscii'
    end

    def test_the_source
      tbg = config.source('tbg')
      assert tbg.enabled?
      assert_equal TbgZipParser, Parsers.for(tbg.format)
      assert_match tbg.link, '/bbslist/ibbs1126.zip'
      refute_match tbg.link, '/bbslist/ibbs110126.zip'
      assert_operator config.priority.index('sbl'), :<, config.priority.index('tbg')
      assert_operator config.priority.index('tbg'), :<, config.priority.index('syncterm')
    end
  end
end
