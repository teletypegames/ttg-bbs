# frozen_string_literal: true

require 'test_helper'

class GameModelTest < Minitest::Test
  def test_a_record_is_cleaned
    g = GameModel.from_record({ 'id' => 'Q1', 't' => " Zork\e[2J ", 'w' => "Zork\u202e",
                                'pub' => ["Info\ecom", "\e", 'Infocom'] })
    assert_equal ['Zork[2J', 'Zork', ['Infocom']], [g.title, g.article, g.publishers]
  end

  def test_a_record_without_an_id_or_title_is_no_game
    assert_nil GameModel.from_record({ 'id' => 'x', 't' => 'Zork' })
    assert_nil GameModel.from_record({ 'id' => 'Q1', 't' => "\e" })
  end
end
