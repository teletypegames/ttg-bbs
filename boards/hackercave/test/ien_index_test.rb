# frozen_string_literal: true

require 'test_helper'

class IenIndexTest < Minitest::Test
  include TempDir

  def test_rows_continuations_dates_and_texts
    entries = ien_index.entries
    assert_equal [1, 4, 7, 137], entries.map(&:number)
    assert_equal 'Issues in the Interconnection of Datagram Networks', entries[0].title
    assert_equal %w[1977-07-29 1977-07 1980-04-01], entries.values_at(0, 2, 3).map(&:date)
    assert_equal '', entries[2].author
    assert_equal ['TXT PDF', 'PDF', 'PDF', 'TXT PDF'], entries.map(&:formats)
  end
end
