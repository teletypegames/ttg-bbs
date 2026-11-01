# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../../lib/domain/discovery'

module Discovery
  # What the tests of Global Discovery share: the fixtures, a catalog in a
  # temporary folder, sources and probe results.
  module TestHelper
    FIXTURES = File.expand_path('../fixtures/discovery', __dir__)
    CONFIG   = File.join(Root::ROOT, 'config/discovery')

    def fixture(name) = File.binread(File.join(FIXTURES, name))

    def source(id = 'test', format: 'nodelist', network: nil, member: nil)
      SourceModel.new(id: id, name: id.capitalize, url: "https://#{id}.example.org/list", format: format,
                      member: member, network: network, licence: '', attribution: '', enabled: true)
    end

    def config = @config ||= ConfigRepository.new(CONFIG)

    # A catalog in a temporary folder, removed after the test.
    def database
      @tmp = Dir.mktmpdir('discovery-test')
      @db  = Database.new(File.join(@tmp, 'discovery.sqlite3'))
    end

    def teardown
      @db&.close
      FileUtils.rm_rf(@tmp) if @tmp
      super
    end

    def probe(result, at:, banner: '', **rest)
      latency = %w[ok silent closed].include?(result) ? 12 : nil
      ProbeResultModel.new(result: result, at: at, latency_ms: latency, ip: rest.fetch(:ip, '192.0.2.10'),
                           banner: banner.b, options: rest.fetch(:options, []))
    end
  end
end
