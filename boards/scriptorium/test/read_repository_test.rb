# frozen_string_literal: true

require 'test_helper'

class ReadRepositoryTest < Minitest::Test
  include TempDir

  def setup
    super
    @reads = ReadRepository.new(database)
  end

  def test_counts_the_reads_of_a_book
    assert_predicate @reads, :empty?
    2.times { @reads.add(1342) }
    @reads.add(11)

    assert_equal 2, @reads.count(1342)
    assert_equal 0, @reads.count(84)
    refute_predicate @reads, :empty?
  end

  def test_top_puts_the_most_read_first_and_breaks_ties_by_number
    [345, 11, 345, 84, 11, 345].each { |id| @reads.add(id) }

    assert_equal [[345, 3], [11, 2], [84, 1]], @reads.top(5)
    assert_equal [[345, 3]], @reads.top(1)
  end
end
