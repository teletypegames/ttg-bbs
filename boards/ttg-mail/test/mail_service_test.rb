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
