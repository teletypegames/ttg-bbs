# frozen_string_literal: true

require 'test_helper'

class MachineModelTest < Minitest::Test
  def test_a_record_becomes_a_clean_machine
    m = MachineModel.from_record({
      'id'  => 'Q1',
      't'   => "C64\e[2J",
      'k'   => 'nonsense',
      'y'   => 1982,
      'e'   => 1994,
      'mak' => ['Commodore', "Commodore\e"]
    })
    assert_equal ['C64[2J', 'pc', '1982–1994', ['Commodore']], [m.name, m.kind, m.years, m.makers]
    assert_nil MachineModel.from_record({ 'id' => 'x', 't' => 'C64' })
  end

  def test_facts_show_a_dash_for_the_core_ones
    Dir.mktmpdir do |dir|
      c     = sample_catalog(dir)
      facts = UI::Wording.facts(c.find('Q5'), c).to_h
      assert_equal %w[— — — —], facts.values_at('Years', 'Maker', 'CPU', 'Memory')
      refute facts.key?('Sold')
      c64 = UI::Wording.facts(c.find('Q99775'), c).to_h
      assert_equal ['17,000,000 units', 'Commodore VIC-20', 'United States'], c64.values_at('Sold', 'Before', 'Origin')
    end
  end
end
