# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/ui/arts'

# The river town of lib/content/network.yml: every board has a building on each map, inside the
# town, and no building or name covers another's.
class TownMapTest < Minitest::Test
  # The name under a building on each face: [width, cells left of the building].
  LABELS = { modern: [18, 3], c64: [9, 3] }.freeze

  def boards = NetworkRepository.new(File.join(TeletypeBBS::CONTENT_DIR, 'network.yml')).boards

  def test_every_board_stands_inside_the_town_on_both_maps
    %i[modern c64].each do |face|
      town = UI::Arts.load(face, 'town')
      boards.each do |b|
        cells(face, b).each do |col, row|
          assert col.between?(0, town.cols - 1) && row.between?(0, town.rows - 1), "#{b.id} leaves the #{face} town"
        end
      end
    end
  end

  def test_no_building_or_name_covers_another
    %i[modern c64].each do |face|
      taken = {}
      boards.each do |b|
        cells(face, b).each do |cell|
          refute taken.key?(cell), "#{b.id} covers #{taken[cell]} on the #{face} map at #{cell}"
          taken[cell] = b.id
        end
      end
    end
  end

  def test_the_museum_has_its_plot
    siliconia = boards.find { |b| b.id == 'siliconia-bbs' }
    assert_equal({ modern: [22, 18], c64: [13, 12] }, siliconia.place)
    assert_operator siliconia.short.size, :<=, 7
  end

  private

  # The cells of +board+'s building and of its name (without the blank margins of the name).
  def cells(face, board)
    col, row = board.place.fetch(face)
    art = UI::Arts.load(face, "building_#{board.id}")
    building = (0...art.rows).flat_map { |r| (0...art.cols).map { |c| [col + c, row + r] } }
    building + name_cells(face, board, col, row + art.rows)
  end

  def name_cells(face, board, col, row)
    width, left = LABELS.fetch(face)
    name  = face == :modern ? board.name : board.short
    start = col - left + ((width - name.size) / 2)
    (0...name.size).map { |i| [start + i, row] }
  end
end
