# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/mock'
require 'json'
require 'tmpdir'
require 'bbs'
require_relative '../lib/domain'

# Answers BBS::HTTP.get with the JSON the block gives for the request's
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
    BBS::HTTP::Response.new(status: @status, body: JSON.generate(@answer.call(params)), headers: {})
  end

  def serve(&) = BBS::HTTP.stub(:get, ->(url, **options) { get(url, **options) }, &)
end

# A fresh data directory for each test.
module TmpData
  def setup
    super
    @dir = Dir.mktmpdir('commodex-bbs-test')
  end

  def teardown
    FileUtils.remove_entry(@dir)
    super
  end

  def path(name) = File.join(@dir, name)
end

# A game of the catalog, by QID and title.
def game(id, title, **lists) = GameModel.from_record({ 'id' => id, 't' => title, **lists.transform_keys(&:to_s) })
