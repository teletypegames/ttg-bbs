# frozen_string_literal: true

require_relative 'test_helper'
require 'bbs/test'
require_relative '../lib/ui'

# The board's face around the gem's debrief: the goodbye comes after a
# refused code too.
class UITest < Minitest::Test
  include TmpData

  def face
    sessions = SessionService.new(SessionRepository.new(path('sessions.sqlite3')))
    BBS::Flow.define do
      call(&UI.debrief(Impostor::Modern.flow(sessions: sessions)))
      call { UI.goodbye(session) }
    end
  end

  def keys(*lines) = lines.flat_map { |l| [*l.chars, :enter] }

  def test_a_refused_code_still_says_goodbye
    session = BBS::Test::Session.new(keys: keys('nor', 'BADBAD'))
    BBS::FlowRunner.new(session, 'test', face).run

    assert_includes session.output, 'Access denied. Code mismatch.'
    assert_includes session.output, 'Thanks for calling'
  end

  def test_the_c64_goodbye_has_the_logo
    session = BBS::Test::Session.new(petscii: true)
    UI::Petscii.goodbye(session)

    assert_includes session.output, 'Thanks for calling Impostor BBS'
    assert_includes session.output, UI::Petscii::LOGO.first
  end
end
