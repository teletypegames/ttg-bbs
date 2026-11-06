# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/mock'
require 'json'
require 'rubbs'
require_relative '../lib/domain'

# Answers Rubbs::Common::Web::HTTP.get from a table of path => [status, body], and records
# the URLs asked for.
class FakeWiki
  attr_reader :urls

  def initialize(routes)
    @routes = routes
    @urls   = []
  end

  def get(url, **options)
    @urls << [url, options]
    path = URI(url).path
    status, body = @routes.fetch(path) { raise Rubbs::Common::Web::HTTP::Error, "no answer from #{path}" }
    Rubbs::Common::Web::HTTP::Response.new(status: status, body: body.is_a?(String) ? body : JSON.generate(body), headers: {})
  end

  # Runs the block with Rubbs::Common::Web::HTTP.get answered by this fake.
  def serve(&) = Rubbs::Common::Web::HTTP.stub(:get, ->(url, **options) { get(url, **options) }, &)
end
