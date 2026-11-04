# frozen_string_literal: true

require 'test_helper'

class ReadModelTest < Minitest::Test
  include TempDir

  def test_counts_the_reads_of_a_book
    assert_predicate ReadModel, :none?
    2.times { ReadModel.add(1342) }
    ReadModel.add(11)

    assert_equal 2, ReadModel.count_of(1342)
    assert_equal 0, ReadModel.count_of(84)
    refute_predicate ReadModel, :none?
  end

  def test_top_puts_the_most_read_first_and_breaks_ties_by_number
    [345, 11, 345, 84, 11, 345].each { |id| ReadModel.add(id) }

    assert_equal [[345, 3], [11, 2], [84, 1]], ReadModel.top(5)
    assert_equal [[345, 3]], ReadModel.top(1)
  end
end
