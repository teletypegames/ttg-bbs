# frozen_string_literal: true

require 'test_helper'

class DownloadModelTest < Minitest::Test
  include BoardTest

  def test_counts_downloads_by_title
    assert DownloadModel.empty?
    2.times { DownloadModel.add('c64/GAME.PRG', version: '1.0', protocol: :zmodem) }
    DownloadModel.add('c64/OTHER.PRG', version: '2.0', protocol: :xmodem)

    refute DownloadModel.empty?
    assert_equal 2, DownloadModel.of('c64/GAME.PRG')
    assert_equal 0, DownloadModel.of('plus4/GAME.PRG')
    assert_equal %w[1.0 zmodem], DownloadModel.first.values.values_at(:version, :protocol)
  end

  def test_keeps_the_rows_across_a_restart
    path = File.join(@dir, 'warp-engine.sqlite3')
    BBS::Model.bind(main: BBS::Database.open(path, MIGRATIONS))
    DownloadModel.add('c64/GAME.PRG', version: '1.0', protocol: :xmodem_1k)
    DownloadModel.db.disconnect

    BBS::Model.bind(main: BBS::Database.open(path, MIGRATIONS))
    assert_equal 1, DownloadModel.of('c64/GAME.PRG')
  end
end
