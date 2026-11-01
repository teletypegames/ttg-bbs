# frozen_string_literal: true

require_relative 'test_helper'
require 'zlib'

module Discovery
  class GeoipTest < Minitest::Test
    include TestHelper

    CSV = <<~CSV
      0.0.0.0,0.255.255.255,ZZ
      192.0.2.0,192.0.2.255,HU
      198.51.100.0,198.51.100.127,US
      2001:db8::,2001:db8::ffff,DE
    CSV

    class Fetcher
      attr_reader :urls

      def initialize(body)
        @body = body
        @urls = []
      end

      def get(uri)
        @urls << uri.to_s
        raise SourceFetcher::FetchError, 'not out yet' if uri.to_s.include?('2026-12')

        @body
      end
    end

    def setup
      database
      io = StringIO.new
      gz = Zlib::GzipWriter.new(io)
      gz.write(CSV)
      gz.close
      @fetcher = Fetcher.new(io.string)
      @geoip = GeoipRepository.new(File.join(@tmp, 'geoip'), fetcher: @fetcher)
    end

    def test_lookup
      assert_nil @geoip.country('192.0.2.1')
      @geoip.install('2026-11', @fetcher.get(URI('https://x/2026-11')))
      assert_equal 'hu', @geoip.country('192.0.2.1')
      assert_equal 'us', @geoip.country('198.51.100.5')
      assert_nil @geoip.country('198.51.100.200')
      assert_nil @geoip.country('0.1.2.3')
      assert_equal 'de', @geoip.country('2001:db8::1')
      assert_nil @geoip.country('2001:db9::1')
      assert_nil @geoip.country('nonsense')
    end

    def test_monthly_refresh_falls_back_to_the_last_month
      assert_equal '2026-11', @geoip.refresh(Time.utc(2026, 12, 1))
      assert_equal 2, @fetcher.urls.size
      assert_match(/dbip-country-lite-2026-11\.csv\.gz/, @fetcher.urls.last)
      assert_equal '2026-11', @geoip.refresh(Time.utc(2026, 12, 1, 1))
      assert_equal 2, @fetcher.urls.size
    end
  end
end
