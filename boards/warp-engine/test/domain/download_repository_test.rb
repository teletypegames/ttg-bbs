# frozen_string_literal: true

require 'test_helper'

class DownloadRepositoryTest < Minitest::Test
  include BoardTest

  def test_counts_downloads_by_title
    downloads = DownloadRepository.new(database)
    assert downloads.empty?
    2.times { downloads.add('c64/GAME.PRG', version: '1.0', protocol: :zmodem) }
    downloads.add('c64/OTHER.PRG', version: '2.0', protocol: :xmodem)

    refute downloads.empty?
    assert_equal 2, downloads.count('c64/GAME.PRG')
    assert_equal 0, downloads.count('plus4/GAME.PRG')
  end

  def test_keeps_the_rows_across_a_restart
    DownloadRepository.new(database).add('c64/GAME.PRG', version: '1.0', protocol: :xmodem_1k)

    assert_equal 1, DownloadRepository.new(database).count('c64/GAME.PRG')
  end
end
