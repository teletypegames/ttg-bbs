# frozen_string_literal: true

require_relative 'test_helper'

# A caller's mailbox at a glance, from what the Central answers.
class MailServiceTest < Minitest::Test
  Answers = Struct.new(:answer) do
    def call(_op, _actor) = answer
  end

  def service(answer) = MailService.new(-> { Answers.new(answer) })

  def ada = Rubbs::Common::Central::Actor.new(id: 1, name: 'Ada')

  def test_the_new_letters
    assert_equal MailboxSummaryModel.new(unread: 3, reachable: true), service({ 'result' => 'ok', 'count' => 3 }).summary(ada)
  end

  def test_a_guest_has_none
    assert_equal 0, service({ 'result' => 'ok', 'count' => 3 }).summary(Rubbs::Common::Central::Actor.guest('Joe')).unread
  end

  def test_the_central_away
    refute service({ 'result' => 'unavailable' }).summary(ada).reachable
  end
end

# The post office's desk: the letters and the wall, kept a while.
class DeskTest < Minitest::Test
  Proxy = Struct.new(:answers, :asked) do
    def call(op, _actor, **)
      asked << op
      answers.fetch(op)
    end
  end

  def test_the_desk_of_an_account
    letters = Proxy.new(
      {
        unread: { 'result' => 'ok', 'count' => 1 },
        inbox:  {
          'result'  => 'ok',
          'letters' => [{ 'from_name' => 'Bob', 'subject' => 'Hi', 'read_at' => nil }]
        }
      },
      []
    )
    walls = Proxy.new({ recent: { 'result' => 'ok', 'notes' => [{ 'name' => 'Joe', 'text' => 'hello' }] } }, [])
    now = Time.at(0)
    service = MailService.new(-> { letters }, -> { walls }, clock: -> { now })
    desk = service.desk(Rubbs::Common::Central::Actor.new(id: 1, name: 'Ada'))
    assert_equal [1, [{ from: 'Bob', subject: 'Hi', new: true }], [{ name: 'Joe', text: 'hello' }]],
                 [desk.summary.unread, desk.letters, desk.notes]
    service.desk(Rubbs::Common::Central::Actor.new(id: 1, name: 'Ada'))
    assert_equal %i[unread inbox], letters.asked
  end

  def test_the_central_away
    letters = Proxy.new({ unread: { 'result' => 'unavailable' } }, [])
    desk = MailService.new(-> { letters }).desk(Rubbs::Common::Central::Actor.new(id: 1, name: 'Ada'))
    assert_equal DeskModel.away, desk
  end
end
