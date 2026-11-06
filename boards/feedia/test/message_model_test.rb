# frozen_string_literal: true

require_relative 'test_helper'
require 'ttg/common'

# The inbox of before the network's feedback, handed over to it once.
class MessageModelTest < Minitest::Test
  include TmpDir

  def setup
    super
    Rubbs::Test.auth_secret
    @server = Rubbs::Common::Central::Server.new(services: [TTG::Feedback::Service], data: path('central'))
    Rubbs.config.central = Rubbs::Common::Central::Link.new(server: @server)
    MessageModel.create(kind: 'suggestion', at: '2026-10-01T10:00:00Z', sender: 'Joe', name: 'Lobsters', url: 'https://lobste.rs/rss')
    MessageModel.create(kind: 'feedback', at: '2026-10-02T10:00:00Z', sender: nil, text: 'Lovely board')
  end

  def teardown
    Rubbs.config.central = nil
    @server.stop
    Rubbs.config.auth_secrets = []
    super
  end

  def test_a_suggestion_is_a_feed
    feed = MessageModel.first.to_feedback
    assert_equal ['feed', 'Joe', 'Lobsters', 'https://lobste.rs/rss', 'read'],
                 feed.values_at(:kind, :name, :subject, :link, :state)
  end

  def test_the_inbox_is_handed_over_once
    capture_io { assert_equal 2, FeediaBBS.allocate.export_inbox }
    assert_equal 0, FeediaBBS.allocate.export_inbox
    kinds = @server.services['/feedback'].store.list[:items].map { |item| [item[:kind], item[:board]] }
    assert_equal [%w[feedback bbs], %w[feed bbs]], kinds
  end

  def test_nothing_is_lost_when_the_central_is_away
    Rubbs.config.central = nil
    assert_raises(RuntimeError) { capture_io { FeediaBBS.allocate.export_inbox } }
    assert_equal 2, MessageModel.unexported(10).size
  end
end
