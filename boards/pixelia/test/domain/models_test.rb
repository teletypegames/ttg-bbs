# frozen_string_literal: true

require 'test_helper'

class ModelsTest < Minitest::Test
  def sauce_record(title)
    record = +'SAUCE00'.b
    record << title.b.ljust(35, ' ') << 'author'.ljust(20) << 'group'.ljust(20) << '19960101'
    record << ("\0" * 4) << [1, 1].pack('CC') << [80, 25].pack('vv') << [0, 0].pack('vv') << [0, 1].pack('CC')
    record.ljust(SauceModel::SIZE, "\0".b)
  end

  def test_sauce_texts_lose_their_control_characters
    sauce = SauceModel.parse("art\x1A#{sauce_record("Evil\e]0;x\x07")}")
    assert_equal 'Evil]0;x', sauce.title
    assert_equal 'author', sauce.author
    assert_equal 80, sauce.width
    assert sauce.ice?
  end

  def test_canvas_round_trip
    canvas = painted_canvas
    assert_equal canvas.at(0, 0), CanvasModel.from_h(JSON.parse(JSON.generate(canvas.to_h))).at(0, 0)
    assert_nil CanvasModel.from_h({ 'chars' => ['x'] })
  end

  def test_canvas_cell_rules
    assert_equal ['A', 2, 0], CanvasService.cell('A', 2, false)
    assert_equal ['A', 0, 2], CanvasService.cell('A', 2, true)
    assert_equal ['│', 1, 0], CanvasService.cell('|', 1, false)
    assert_nil CanvasService.cell("\e", 1, false)
  end
end
