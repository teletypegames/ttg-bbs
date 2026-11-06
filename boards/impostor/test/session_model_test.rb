# frozen_string_literal: true

require 'test_helper'

class SessionModelTest < Minitest::Test
  def test_fields_are_cleaned_trimmed_and_cut
    fields = SessionModel.fields(player_name: "  N\eOR ", feedback: "x\u202e#{'y' * 2000}")
    assert_equal 'NOR', fields[:player_name]
    assert_equal 1000, fields[:feedback].length
    refute_includes fields[:feedback], "\u202e"
  end

  def test_a_player_name_is_one_to_three_letters
    %w[A JD ATM].each { |name| assert_equal({ player_name: name }, SessionModel.fields(player_name: name)) }
    ['ARPI', 'GET / HTTP/1.0', 'Host: 84.46.247.37:2324', 'IEURANDOM1RANDOM2RANDOM3RANDOM4/', 'A1', 'ÁRP', '', 'A]R?21@$T`N<#3N']
      .each { |junk| assert_empty SessionModel.fields(player_name: junk), junk }
  end

  def test_a_code_is_letters_and_digits
    assert_equal({ code: '265LFI' }, SessionModel.fields(code: '265LFI'))
    assert_empty SessionModel.fields(code: 'Host: 84.46.247.37:2324')
  end

  def test_a_step_with_a_junk_player_name_is_no_player
    assert SessionModel.player?(player_name: 'ATM', code: '265LFI')
    assert SessionModel.player?(feedback: 'Great!')
    refute SessionModel.player?(player_name: 'GET / HTTP/1.0', code: '90')
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
