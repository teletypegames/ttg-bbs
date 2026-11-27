# frozen_string_literal: true

require_relative '../test_helper'

# SERMO is a Kvartet of 1977: today's day, the year the machine lives in.
class SermoTest < Minitest::Test
  def test_today_is_in_the_year_of_the_machine
    assert_equal '1977-11-27', Sermo.today(Time.new(2026, 11, 27))
    assert_equal '1977-02-28', Sermo.today(Time.new(2028, 2, 29))
  end

  def test_no_later_years_on_the_digital_side
    source = File.read(File.expand_path('../../lib/sermo/sermo_os.rb', __dir__))
    printed = source.scan(/(?:print|puts) ['"]([^'"]*)['"]/).flatten.join("\n")
    ['Solus', 'Sonus', 'Personal Tape', '2026', 'Works', 'C:'].each { |word| refute_includes printed, word }
  end
end
