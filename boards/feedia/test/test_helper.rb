# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'domain'
require 'rubbs/test'

# A test that works in a directory of its own, removed after it, and on a
# fresh database.
module TmpDir
  def setup
    super
    @dir = Dir.mktmpdir('feedia-test')
    Rubbs::Test.database(MIGRATIONS)
  end

  def teardown
    FileUtils.rm_rf(@dir)
    super
  end

  def path(name) = File.join(@dir, name)
end

# Rubbs::Common::Web::HTTP for a test: every GET answers +body+ (or raises +error+) and is
# counted; +delay+ seconds make concurrent callers overlap.
class FakeHTTP
  attr_reader :calls

  def initialize(body: nil, status: 200, error: nil, delay: 0)
    @body   = body
    @status = status
    @error  = error
    @delay  = delay
    @calls  = 0
    @mu     = Mutex.new
  end

  def get(_url, **)
    @mu.synchronize { @calls += 1 }
    sleep @delay
    raise @error if @error

    Rubbs::Common::Web::HTTP::Response.new(status: @status, body: @body.dup.force_encoding(Encoding::BINARY), headers: {})
  end
end

# The Discord webhook for a test: the posts are kept.
class FakeDiscord
  attr_reader :posts

  def initialize = @posts = []

  def post(content) = @posts << content
end
