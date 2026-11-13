# frozen_string_literal: true

require 'test_helper'

class CollectionTest < Minitest::Test
  include TmpData

  def setup
    super
    Rubbs::Test.database(MIGRATIONS)
    @catalog = sample_catalog(@dir)
    @c64     = @catalog.find('Q99775')
  end

  def test_marks_toggle_and_count
    marks = CollectionService.new(catalog: @catalog)
    assert_equal :account, marks.toggle(guest, @c64, 'owned')
    assert_equal :added, marks.toggle(account, @c64, 'grew_up')
    assert_equal :added, marks.toggle(account(8, 'Bob'), @c64, 'grew_up')
    assert marks.marked?(account, @c64, 'grew_up')
    assert_equal({ 'owned' => 0, 'grew_up' => 2 }, marks.counts(@c64))
    assert_equal [[@c64, 2]], marks.grew_up_on
    assert_equal :removed, marks.toggle(account, @c64, 'grew_up')
    assert_empty marks.of(account)
  end

  def test_a_memory_is_refused_to_a_guest_and_when_empty_or_long
    memories = MemoryService.new(catalog: @catalog)
    assert_equal :account, memories.submit(@c64, identity: guest, text: 'hi', caller: 'a')
    assert_equal :empty, memories.submit(@c64, identity: account, text: "  \n", caller: 'a')
    assert_equal :too_long, memories.submit(@c64, identity: account, text: 'x' * 601, caller: 'a')
  end

  def test_memories_wait_for_an_admin
    memories = MemoryService.new(catalog: @catalog)
    assert_equal :ok, memories.submit(@c64, identity: account, text: "LOAD \"*\",8,1\e", caller: 'a')
    assert_equal :rate_limited, memories.submit(@c64, identity: account, text: 'again', caller: 'a')
    assert_equal 0, memories.count(@c64)
    assert_equal :ok, memories.approve(memories.pending.first.id)
    assert_equal ['LOAD "*",8,1'], memories.memories(@c64).map(&:text)
    assert_equal [@c64], memories.machines_with_memories
    assert_equal :no_memory, memories.reject(99)
  end
end
