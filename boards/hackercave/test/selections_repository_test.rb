# frozen_string_literal: true

require 'test_helper'

class SelectionsRepositoryTest < Minitest::Test
  include TempDir

  def test_the_board_selections_load
    selections = SelectionsRepository.new(File.expand_path('../config/selections.yml', __dir__))
    assert_equal ['Classics', 'Telnet', 'April 1st'], selections.all.map(&:name)
    assert(selections.all.all? { |s| s.entries.all? { |n, title, _| n.positive? && !title.empty? } })
  end

  def test_a_broken_file_gives_no_selections
    File.write(path('selections.yml'), "- name: x\n")
    assert_empty SelectionsRepository.new(path('selections.yml')).all
  end
end
