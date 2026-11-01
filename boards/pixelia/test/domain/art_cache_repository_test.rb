# frozen_string_literal: true

require 'test_helper'

class ArtCacheRepositoryTest < Minitest::Test
  include TmpDir

  def test_keeps_files_and_drops_the_least_recently_used
    cache = ArtCacheRepository.new(@dir, max_bytes: 10)
    cache.write('a', 'aaaa')
    sleep 0.01
    cache.write('b', 'bbbb')
    sleep 0.01
    assert_equal 'aaaa', cache.read('a')
    cache.write('c', 'cccc')
    assert_nil cache.read('b')
    assert_equal 'aaaa', cache.read('a')
    assert_equal 'cccc', ArtCacheRepository.new(@dir, max_bytes: 10).read('c')
    assert_empty Dir.glob(File.join(@dir, '*.tmp'))
  end

  def test_a_file_bigger_than_the_cache_is_not_kept
    cache = ArtCacheRepository.new(@dir, max_bytes: 3)
    cache.write('a', 'aaaa')
    assert_nil cache.read('a')
  end
end
