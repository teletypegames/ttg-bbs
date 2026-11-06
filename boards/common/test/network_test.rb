# frozen_string_literal: true

require_relative 'test_helper'
require 'rubbs/test'
require 'tmpdir'

# The network's services on a Central in the test's process: the accounts,
# Feedback, the Wall and the letters.
module CentralHelper
  def setup
    Rubbs::Test.auth_secret
    @data     = Dir.mktmpdir('ttg-central')
    @accounts = Rubbs::Test.accounts(roles: ['member'])
    @ada      = @accounts.register('Ada', 'secret1')
    @bob      = @accounts.register('Bob', 'secret2')
    @server   = Rubbs::Common::Central::Server.new(
      services: [Rubbs::Common::Auth::Service, TTG::Feedback::Service, TTG::Wall::Service, TTG::PrivateMessage::Service],
      accounts: @accounts,
      data:     @data
    )
    Rubbs.config.central = Rubbs::Common::Central::Link.new(server: @server)
    Rubbs.config.log_tag = 'test-bbs'
  end

  def teardown
    Rubbs.config.central = nil
    @server.stop
    FileUtils.rm_rf(@data)
    Rubbs.config.auth_secrets = []
  end

  def ada = actor(@ada)

  def actor(identity, key: 'line:1') = Rubbs::Common::Central::Actor.new(id: identity.id, name: identity.name, caller_key: key)

  def guest(name, key: 'line:9') = Rubbs::Common::Central::Actor.guest(name, caller_key: key)

  def quietly(&) = capture_io(&)
end

class NarrativeTest < Minitest::Test
  def test_a_board_overrides_what_it_wants
    narrative = TTG::Narrative.new(TTG::Feedback::DEFAULTS, {
      title:   'Write to the editors',
      petscii: { title: 'EDITORS' },
      kinds:   {
        feed:     {
          label: 'Suggest a feed',
          link:  { label: 'Feed URL', required: true }
        },
        feedback: { label: 'Something else' }
      }
    })
    assert_equal ['Write to the editors', 'EDITORS'], [narrative.text(:title), narrative.text(:title, petscii: true)]
    assert_equal TTG::Feedback::DEFAULTS[:thanks], narrative.text(:thanks)
    assert_equal %i[feed feedback], narrative.kinds.keys
    assert_equal 'Feed URL', narrative.kind(:feed).field(:link)[:label]
    assert_nil narrative.kind(:feedback).field(:link)
  end

  def test_a_misspelt_key_is_an_error_at_boot
    assert_raises(TTG::Narrative::UnknownKey) { TTG::Narrative.new(TTG::Wall::DEFAULTS, { titel: 'x' }) }
    assert_raises(TTG::Narrative::UnknownKey) { TTG::Narrative.new(TTG::Feedback::DEFAULTS, { body: { lable: 'x' } }) }
  end
end

class FeedbackTest < Minitest::Test
  include CentralHelper

  def test_feedback_goes_to_the_sysops
    quietly do
      assert_equal 'ok',
                   TTG::Feedback.box.call(:submit, ada, subject: 'Hi', body: 'A fine board', context: 'Book: Emma')['result']
      assert_equal 'forbidden', TTG::Feedback.box.call(:list, ada)['result']
      @accounts.grant('Ada', 'sysop')
      item = TTG::Feedback.box.call(:list, ada)['items'].first
      assert_equal ['test-bbs', 'feedback', 'A fine board', 'Book: Emma', 'new'],
                   item.values_at('board', 'kind', 'body', 'context', 'state')
      refute item.key?('caller_key')
      assert_equal 'read', TTG::Feedback.box.call(:read, ada, id: item['id'])['item']['state']
      assert_equal 'ok', TTG::Feedback.box.call(:mark, ada, id: item['id'], state: 'done', note: 'thanked')['result']
    end
  end

  def test_what_is_refused
    quietly do
      assert_equal 'empty', TTG::Feedback.box.call(:submit, ada, body: '  ')['result']
      assert_equal 'bad_link', TTG::Feedback.box.call(:submit, ada, body: 'x', link: 'ftp://x')['result']
      assert_equal 'name_taken', TTG::Feedback.box.call(:submit, guest('ada'), body: 'x')['result']
      3.times { assert_equal 'ok', TTG::Feedback.box.call(:submit, guest('Joe'), body: 'x')['result'] }
      assert_equal 'limited', TTG::Feedback.box.call(:submit, guest('Joe'), body: 'x')['result']
      assert_equal 'ok', TTG::Feedback.box.call(:submit, guest(nil, key: 'line:8'), body: 'x')['result']
    end
  end

  def test_discord_hears_only_that_something_came
    posts = []
    hook = Object.new
    hook.define_singleton_method(:post) { |text| posts << text }
    notifier = TTG::Feedback::Notifier.new(nil)
    notifier.instance_variable_set(:@hook, hook)
    notifier.call({ id: 7, board: 'feedia-bbs', kind: 'feed', name: 'Joe', account_id: nil, body: 'secret words' })
    assert_match(/feedia\\-bbs.*feed.*Joe \\\(guest\\\).*#7/, posts.first)
    refute_includes posts.first, 'secret words'
  end

  def test_an_old_box_is_brought_in
    quietly do
      rows = [{ name: 'Joe', subject: 'Old', body: 'From before', created_at: '2026-10-01T10:00:00Z', kind: 'feed' }]
      assert_equal 1, TTG::Feedback.box.call(:import, nil, rows: rows)['count']
      @accounts.grant('Ada', 'sysop')
      assert_equal ['From before', 'read'], TTG::Feedback.box.call(:list, ada)['items'].first.values_at('body', 'state')
    end
  end
end

class WallTest < Minitest::Test
  include CentralHelper

  def test_a_conversation
    quietly do
      first = TTG::Wall.walls.call(:post, ada, text: 'Hello wall')['id']
      assert_equal 'ok', TTG::Wall.walls.call(:post, guest('Joe'), text: 'Hi Ada', reply_to: first)['result']
      notes = TTG::Wall.walls.call(:recent, nil)['notes']
      assert_equal([['Ada', false, nil], ['Joe', true, 'Ada']], notes.map { |n| n.values_at('name', 'guest', 'reply_name') })
      assert_equal(['Hello wall', 'Hi Ada'], TTG::Wall.lines(5).map { |n| n['text'] })
    end
  end

  def test_who_may_write
    quietly do
      assert_equal 'name_needed', TTG::Wall.walls.call(:post, guest(nil), text: 'x')['result']
      assert_equal 'name_taken', TTG::Wall.walls.call(:post, guest('BOB'), text: 'x')['result']
      assert_equal 'ok', TTG::Wall.walls.call(:post, ada, text: 'one')['result']
      assert_equal 'too_soon', TTG::Wall.walls.call(:post, ada, text: 'two')['result']
      assert_equal 'unknown_note', TTG::Wall.walls.call(:post, actor(@bob), text: 'x', reply_to: 999)['result']
    end
  end

  def test_the_sysop_hides_and_bars
    quietly do
      id = TTG::Wall.walls.call(:post, guest('Spammer'), text: 'buy now')['id']
      @accounts.grant('Ada', 'sysop')
      assert_equal 'ok', TTG::Wall.walls.call(:hide, ada, id: id, reason: 'spam')['result']
      assert_empty TTG::Wall.walls.call(:recent, nil)['notes']
      assert_equal 'spam', TTG::Wall.walls.call(:moderation, ada)['notes'].first['reason']
      assert_equal 'ok', TTG::Wall.walls.call(:bar, ada, id: id, hours: 1)['result']
      assert_equal 'barred', TTG::Wall.walls.call(:post, guest('Other'), text: 'again')['result']
    end
  end

  def test_every_board_on_the_gate
    quietly do
      TTG::Wall.walls.call(:post, ada, text: 'here')
      TTG::Wall.walls.call(:import, nil, rows: [{ board: 'feedia-bbs', name: 'Old', text: 'from before' },
                                                { board: 'feedia-bbs', name: 'ada', text: 'mine' }])
      assert_equal 1, TTG::Wall.lines(10).size
      every = TTG::Wall.lines(10, board: nil)
      assert_equal(%w[test-bbs feedia-bbs feedia-bbs], every.map { |n| n['board'] })
      assert_equal([['Old', true], ['Ada', false]], every.last(2).map { |n| n.values_at('name', 'guest') })
    end
  end
end

class PrivateMessageTest < Minitest::Test
  include CentralHelper

  def test_letters_between_accounts
    quietly do
      assert_equal 'ok', TTG::PrivateMessage.mail.call(:write, ada, to: 'bob', subject: 'Hi', body: 'Hello Bob')['result']
      assert_equal 1, TTG::PrivateMessage.mail.call(:unread, actor(@bob))['count']
      letter = TTG::PrivateMessage.mail.call(:inbox, actor(@bob))['letters'].first
      assert_equal 'Hello Bob', TTG::PrivateMessage.mail.call(:read, actor(@bob), id: letter['id'])['letter']['body']
      assert_equal 0, TTG::PrivateMessage.mail.call(:unread, actor(@bob))['count']
      assert_equal 'guest', TTG::PrivateMessage.mail.call(:write, guest('Joe'), to: 'bob', body: 'x')['result']
      assert_equal 'too_soon', TTG::PrivateMessage.mail.call(:write, ada, to: 'bob', body: 'again')['result']
      TTG::PrivateMessage.mail.call(:block, actor(@bob), name: 'Ada')
      assert_equal 'unknown_account', TTG::PrivateMessage.mail.call(:write, ada, to: 'bob', body: 'again')['result']
    end
  end
end

class ScreensTest < Minitest::Test
  include CentralHelper

  def test_feedback_on_a_modern_terminal
    keys = [*'Joe'.chars, :enter, *'Hi'.chars, :enter, *'Hello'.chars, :ctrl_s, 'x']
    session = Rubbs::Test::Session.new(keys: keys)
    quietly { TTG::Feedback.open(session, narrative: { kinds: { feedback: { label: 'Feedback' } } }) }
    assert_includes session.output, 'Thank you'
  end

  def test_the_wall_on_a_c64
    quietly { TTG::Wall.walls.call(:post, ada, text: 'Hello from Ada') }
    session = Rubbs::Test::Session.new(keys: ['b'], petscii: true)
    quietly { TTG::Wall.open(session) }
    assert_includes session.output.downcase, 'hello from ada'
  end
end
