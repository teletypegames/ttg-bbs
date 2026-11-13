# frozen_string_literal: true

require 'test_helper'

class HeraldServiceTest < Minitest::Test
  include TmpData

  def test_the_machine_of_the_week_stays_all_week
    catalog = sample_catalog(@dir)
    monday  = Time.local(2026, 11, 9, 9)
    assert_equal catalog.machine_of_the_week(monday), catalog.machine_of_the_week(Time.local(2026, 11, 15, 23))
    assert_includes %w[Q918232 Q1115919], catalog.machine_of_the_week(monday).id
  end

  def test_the_note_is_written_once_a_week
    monday = Time.local(2026, 11, 9, 9)
    herald = HeraldService.new(catalog: sample_catalog(@dir), path: path('herald.json'))
    assert_equal :written, herald.publish(monday)
    assert_equal :same, herald.publish(monday + 3600)
    note = JSON.parse(File.read(path('herald.json')))
    assert_equal ['siliconia-bbs', 'Machine of the week', '2026-W46'], note.values_at('board', 'heading', 'week')
    assert_equal Time.local(2026, 11, 16).utc.iso8601, note['until']
  end
end
