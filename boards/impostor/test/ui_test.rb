# frozen_string_literal: true

require_relative 'test_helper'
require 'rubbs/test'
require_relative '../lib/ui'

# The board's face around the gem's debrief: the goodbye comes after a
# refused code too.
class UITest < Minitest::Test
  include TmpData

  def face
    sessions = SessionService.new(SessionRepository.new(path('sessions.sqlite3')))
    Rubbs::Common::Call::Flow.define do
      flow Impostor::Modern.flow(sessions: sessions)
      goodbye(**UI::GOODBYE)
    end
  end

  def keys(*lines) = lines.flat_map { |l| [*l.chars, :enter] }

  def test_a_refused_code_still_says_goodbye
    session = Rubbs::Test::Session.new(keys: keys('nor', 'BADBAD'))
    Rubbs::Common::Call::FlowRunner.new(session, 'test', face).run

    assert_includes session.output, 'Access denied. Code mismatch.'
    assert_includes session.output, 'Thanks for calling'
  end

  def test_the_c64_goodbye_has_the_logo
    session = Rubbs::Test::Session.new(petscii: true)
    Rubbs::Common::Call::Goodbye.show(session, **UI::GOODBYE)

    assert_includes session.output, 'Thanks for calling Impostor BBS'
    assert_includes session.output, UI::LOGO.first
  end
end
