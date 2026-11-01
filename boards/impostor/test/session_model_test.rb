# frozen_string_literal: true

require 'test_helper'

class SessionModelTest < Minitest::Test
  def test_fields_are_cleaned_trimmed_and_cut
    fields = SessionModel.fields(player_name: "  NOR\e[2JMAN ", feedback: "x\u202e#{'y' * 2000}")
    assert_equal 'NOR[2JMAN', fields[:player_name]
    assert_equal 1000, fields[:feedback].length
    refute_includes fields[:feedback], "\u202e"
  end

  def test_a_valid_email_is_kept_as_typed
    assert_equal({ email: 'Norman@Example.com' }, SessionModel.fields(email: ' Norman@Example.com '))
  end

  def test_an_invalid_email_is_left_out
    assert_empty SessionModel.fields(email: 'not an email')
    assert_empty SessionModel.fields(email: "a@b.c\e]52;c;evil\a")
    assert_empty SessionModel.fields(email: "#{'a' * 250}@b.cd")
  end

  def test_unknown_fields_are_left_out
    assert_empty SessionModel.fields(session_id: 'x', password: 'secret')
  end
end
