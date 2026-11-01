# frozen_string_literal: true

require_relative 'test_helper'

module Discovery
  # How the importer downloads and unpacks a source list: only on the public
  # internet, and no member may grow past its cap.
  class FetchTest < Minitest::Test
    include TestHelper

    # A .zip of one deflated member, +name+ holding +data+.
    def zip(name, data)
      deflated = Zlib::Deflate.new(Zlib::BEST_COMPRESSION, -Zlib::MAX_WBITS).then { |z| z.deflate(data, Zlib::FINISH) }
      crc = Zlib.crc32(data)
      local = ['PK', 3, 4, 20, 0, 8, 0, 0, crc, deflated.bytesize, data.bytesize, name.bytesize, 0].pack('a2CCvvvvvVVVvv')
      central = ['PK', 1, 2, 20, 20, 0, 8, 0, 0, crc, deflated.bytesize, data.bytesize, name.bytesize, 0, 0, 0, 0, 0, 0]
                .pack('a2CCvvvvvvVVVvvvvvVV')
      dir_offset = local.bytesize + name.bytesize + deflated.bytesize
      central_dir = central + name
      eocd = ['PK', 5, 6, 0, 0, 1, 1, central_dir.bytesize, dir_offset, 0].pack('a2CCvvvvVVv')
      local + name + deflated + central_dir + eocd
    end

    def test_a_member_comes_out_whole
      assert_equal 'hello' * 1000, ZipReader.read(zip('LIST.001', 'hello' * 1000), /\ALIST/)
      assert_equal ['LIST.001'], ZipReader.names(zip('LIST.001', 'x'))
    end

    def test_a_zip_bomb_stops_at_the_cap
      bomb = zip('LIST.001', "\0" * (4 * 1024 * 1024))
      assert_operator bomb.bytesize, :<, 10_000
      error = assert_raises(ArgumentError) { ZipReader.read(bomb, /\ALIST/, max: 1024 * 1024) }
      assert_match(/too big/, error.message)
    end

    def test_a_member_that_lies_about_its_size_stops_at_the_cap_too
      bomb = zip('LIST.001', "\0" * (2 * 1024 * 1024))
      at = bomb.index("PK\x01\x02".b) + 24
      bomb[at, 4] = [10].pack('V')
      assert_raises(ArgumentError) { ZipReader.read(bomb, /\ALIST/, max: 1024 * 1024) }
    end

    def test_a_broken_directory_is_an_argument_error
      bytes = zip('LIST.001', 'x')
      assert_raises(ArgumentError) { ZipReader.read(bytes[0, 10] + bytes[-22..], /x/) }
    end

    def test_no_list_is_fetched_from_inside_the_network
      fetcher = SourceFetcher.new
      %w[http://127.0.0.1:9/list http://10.0.0.1/list http://169.254.169.254/latest ftp://example.org/list].each do |url|
        assert_raises(SourceFetcher::FetchError) { fetcher.get(URI(url)) }
      end
    end

    def test_every_source_is_fetched_over_https
      config.sources.each { |source| assert source.url.start_with?('https://'), source.id }
    end
  end
end
