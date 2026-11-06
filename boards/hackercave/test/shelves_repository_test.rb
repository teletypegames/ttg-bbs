# frozen_string_literal: true

require 'test_helper'

class ShelvesRepositoryTest < Minitest::Test
  include TempDir

  def test_the_board_shelves_load
    shelves = ShelvesRepository.new(File.expand_path('../config/shelves.yml', __dir__))
    assert_equal ['Classics', 'Telnet', 'April 1st'], shelves.all.map(&:name)
    assert(shelves.all.all? { |s| s.entries.all? { |n, title, _| n.positive? && !title.empty? } })
  end

  def test_a_broken_file_gives_no_shelves
    File.write(path('shelves.yml'), "- name: x\n")
    assert_empty ShelvesRepository.new(path('shelves.yml')).all
  end
end
