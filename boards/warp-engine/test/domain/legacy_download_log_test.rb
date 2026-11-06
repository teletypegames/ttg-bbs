# frozen_string_literal: true

require 'test_helper'

class LegacyDownloadLogTest < Minitest::Test
  include BoardTest

  LOG = <<~JSONL
    {"at":"2026-11-01T09:28:17+01:00","title":"c64/GAME.PRG","version":"2.2.0","protocol":"xmodem_1k"}
    {"at":"2026-11-01T09:30:00+01:00","title":"c64/GAME.PRG","version":"2.2.0","protocol":"zmodem"}
    {"at":"2026-11-01T09:31:00+01:00","title":"plus4/GAME.PRG"
    ["not", "a", "download"]
    {"at":"2026-11-01T09:32:00+01:00","title":"plus4/GAME.PRG","version":"1.0","protocol":"xmodem"}
  JSONL

  def setup
    super
    @path = File.join(@dir, 'downloads.jsonl')
    File.write(@path, LOG)
  end

  def test_imports_the_good_lines_and_renames_the_log
    counts = nil
    assert_output(nil, /downloads: imported 3 from downloads.jsonl \(2 skipped\)/) do
      counts = LegacyDownloadLog.new(@path).import
    end

    assert_equal [3, 2], counts
    assert_equal 2, DownloadModel.of('c64/GAME.PRG')
    assert_equal 1, DownloadModel.of('plus4/GAME.PRG')
    refute File.exist?(@path)
    assert File.exist?("#{@path}.imported")
  end

  def test_leaves_the_log_alone_when_the_table_has_rows
    DownloadModel.add('c64/GAME.PRG', version: '1.0', protocol: :zmodem)

    assert_nil LegacyDownloadLog.new(@path).import
    assert File.exist?(@path)
    assert_equal 1, DownloadModel.of('c64/GAME.PRG')
  end

  def test_does_nothing_without_a_log
    File.delete(@path)

    assert_nil LegacyDownloadLog.new(@path).import
  end
end
