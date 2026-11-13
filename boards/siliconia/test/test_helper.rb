# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/mock'
require 'json'
require 'tmpdir'
require 'rubbs'
require 'rubbs/test'
require_relative '../lib/domain'

# Answers Rubbs::Common::Web::HTTP.get with the JSON the block gives for the request's
# query parameters, and records the requests.
class FakeWikipedia
  attr_reader :requests

  def initialize(status: 200, &answer)
    @status   = status
    @answer   = answer
    @requests = []
  end

  def get(url, **options)
    uri = URI(url)
    @requests << [uri, options]
    params = URI.decode_www_form(uri.query).to_h
    Rubbs::Common::Web::HTTP::Response.new(status: @status, body: JSON.generate(@answer.call(params)), headers: {})
  end

  def serve(&) = Rubbs::Common::Web::HTTP.stub(:get, ->(url, **options) { get(url, **options) }, &)
end

# A fresh data directory for each test.
module TmpData
  def setup
    super
    @dir = Dir.mktmpdir('siliconia-bbs-test')
  end

  def teardown
    FileUtils.remove_entry(@dir)
    super
  end

  def path(name) = File.join(@dir, name)
end

def account(id = 7, name = 'Ada') = Rubbs::Common::Auth::Identity.new(id: id, name: name, source: :login)

def guest = Rubbs::Common::Auth::Identity.guest

# The records of a small catalog: the Commodore line, a Hungarian machine and a sparse console.
RECORDS = [
  {
    'id'  => 'Q918232',
    't'   => 'Commodore VIC-20',
    'k'   => 'home',
    'y'   => 1981,
    'w'   => 'VIC-20',
    'mak' => ['Commodore International'],
    'cpu' => ['MOS Technology 6502'],
    'suc' => ['Q99775']
  },
  {
    'id'   => 'Q99775',
    't'    => 'Commodore 64',
    'k'    => 'home',
    'e'    => 1994,
    'w'    => 'Commodore 64',
    'hw'   => 'Commodore 64',
    'mak'  => ['Commodore International'],
    'mc'   => ['United States'],
    'cpu'  => ['MOS Technology 6510'],
    'sold' => 17_000_000,
    'mem'  => ['64 KiB'],
    'g'    => 2950,
    'pre'  => ['Q918232'],
    'suc'  => ['Q1115919']
  },
  {
    'id'  => 'Q1115919',
    't'   => 'Commodore 128',
    'k'   => 'home',
    'y'   => 1985,
    'mak' => ['Commodore International'],
    'cpu' => ['MOS Technology 8502', 'Zilog Z80'],
    'pre' => ['Q99775']
  },
  {
    'id'  => 'Q832692',
    't'   => 'Videoton TV-Computer',
    'h'   => 'Videoton TVC',
    'k'   => 'home',
    'w'   => 'Videoton TV-Computer',
    'mak' => ['Videoton'],
    'mc'  => ['Hungary'],
    'cpu' => ['Zilog Z80']
  },
  { 'id' => 'Q5', 't' => 'Tele-Spiel', 'k' => 'console' }
].freeze

# A catalog of RECORDS written +at+ as the seed, its Legends the VIC-20 and the C64.
def sample_catalog(dir, wikidata: nil, at: Time.now, ttl: 60)
  seed = File.join(dir, 'seed.json.gz')
  Rubbs::Common::Storage::Snapshot.write(seed, { 'machines' => RECORDS }, at)
  CatalogService.new(
    CatalogService.snapshot(seed: seed, path: File.join(dir, 'catalog.json.gz')),
    wikidata: wikidata,
    ttl:      ttl,
    legends:  %w[Q918232 Q99775 Q404]
  )
end
