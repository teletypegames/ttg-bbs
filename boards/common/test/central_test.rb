# frozen_string_literal: true

require_relative 'test_helper'

class CentralTest < Minitest::Test
  def test_the_gate_is_the_central
    assert_equal 'http://ttg-gate-bbs:8090', TTG::CENTRAL.url
    assert_equal 'http://ttg-gate-bbs:8090/auth', TTG::Auth::URL
    assert_same TTG::CENTRAL, TTG::AUTH.client
  end
end
