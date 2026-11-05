# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/mock'
require 'json'
require 'rubbs'
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
