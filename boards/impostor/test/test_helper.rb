# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'tmpdir'
require 'rubbs'
require_relative '../lib/domain'

# A board on a fresh data directory, removed after each test.
module TmpData
  def setup
    super
    @dir = Dir.mktmpdir('impostor-bbs-test')
  end

  def teardown
    FileUtils.remove_entry(@dir)
    super
  end

  def path(name) = File.join(@dir, name)
end
