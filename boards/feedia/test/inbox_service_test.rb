# frozen_string_literal: true

require 'test_helper'

class InboxServiceTest < Minitest::Test
  include TmpDir

  def setup
    super
    @discord = FakeDiscord.new
    @inbox   = InboxRepository.new(database)
  end

  def service(per_caller: 5, global: 30)
    InboxService.new(@inbox, discord: @discord, per_caller: BBS::RateLimit.new(limit: per_caller, per: 3600),
                             global: BBS::RateLimit.new(limit: global, per: 3600))
  end

  def test_a_suggestion_is_kept_and_rung
    assert_equal :ok, service.suggest(caller: '1.2.3.4', url: ' https://x.example/rss ', name: 'X', from: 'Ada', note: 'good')
    message = @inbox.last(1).first
    assert_equal ['suggestion', 'https://x.example/rss', 'X', 'Ada', 'good'],
                 [message.kind, message.url, message.name, message.from, message.text]
    assert_match(%r{Ada.*suggests a feed: X <https://x.example/rss>}, @discord.posts.first)
  end

  def test_suggestion_checks
    assert_equal :no_url, service.suggest(caller: 'a', url: '  ')
    assert_equal :bad_url, service.suggest(caller: 'a', url: 'ftp://x.example/')
    assert_equal :bad_url, service.suggest(caller: 'a', url: 'https://localhost')
    assert_empty @discord.posts
  end

  def test_feedback_is_cleaned_and_cut
    assert_equal :empty, service.feedback(caller: 'a', text: " \e\a \n")
    assert_equal :ok, service.feedback(caller: 'a', text: "x\e]52;c;AAA\a#{'y' * 2000}", from: "Ev\u202Ee\n")
    message = @inbox.last(1).first
    assert_equal InboxService::MAX_TEXT, message.text.size
    assert_equal 'Eve', message.from
    refute_match(/[\e\a]/, message.text)
  end

  def test_a_caller_is_limited
    inbox = service(per_caller: 2)
    2.times { assert_equal :ok, inbox.feedback(caller: 'a', text: 'hi') }
    refute inbox.open?('a')
    assert_equal :limited, inbox.feedback(caller: 'a', text: 'hi')
    assert inbox.open?('b')
    assert_equal :ok, inbox.feedback(caller: 'b', text: 'hi')
    assert_equal 3, @inbox.count
  end

  def test_all_callers_are_limited_together
    inbox = service(global: 3)
    3.times { |i| assert_equal :ok, inbox.feedback(caller: "c#{i}", text: 'hi') }
    assert_equal :limited, inbox.feedback(caller: 'new', text: 'hi')
    refute inbox.open?('new')
  end

  def test_a_message_the_board_refuses_costs_the_caller_nothing
    per_caller = BBS::RateLimit.new(limit: 1, per: 3600)
    inbox = InboxService.new(@inbox, discord: @discord, per_caller: per_caller, global: BBS::RateLimit.new(limit: 1, per: 3600))
    assert_equal :ok, inbox.feedback(caller: 'a', text: 'hi')
    assert_equal :limited, inbox.feedback(caller: 'b', text: 'hi')
    assert per_caller.room?('b')
  end

  def test_a_message_that_cannot_be_kept_fails
    broken = Object.new
    def broken.append(_) = raise(SQLite3::Exception, 'disk I/O error')
    _, err = capture_io do
      assert_equal :failed, InboxService.new(broken, discord: @discord).feedback(caller: 'a', text: 'hi')
    end
    assert_match(%r{: inbox: SQLite3::Exception: disk I/O error}, err)
    assert_empty @discord.posts
  end

  def test_an_invalid_message_costs_nothing
    inbox = service(per_caller: 1)
    inbox.suggest(caller: 'a', url: 'nope')
    assert_equal :ok, inbox.feedback(caller: 'a', text: 'hi')
  end
end
