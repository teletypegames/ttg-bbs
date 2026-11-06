# frozen_string_literal: true

require_relative '../test_helper'

# The live parts of the clubhouse that come from the network's Central: the
# chimney smoke from the wall, the mailbox from a sysop's feedback.
class SceneServiceTest < Minitest::Test
  include DatabaseCase

  NOW = Time.utc(2026, 11, 6, 12)

  # The site of a board without the network: no team, no events.
  class Offline
    def members = []
    def events = []
  end

  def setup
    super
    @asked = 0
    @notes = []
  end

  def wall = WallService.new(source: ->(_) { (@asked += 1) && @notes })

  def scenes(wall: self.wall, feedback: FeedbackCounter.new(source: ->(_) { { 'counts' => { 'new' => 3 } } }))
    SceneService.new(
      online:       OnlineService.new(OnlineUsersRepository.new),
      wall:         wall,
      feedback:     feedback,
      last_callers: LastCallersService.new,
      site:         SiteService.new(Offline.new),
      door_titles:  []
    )
  end

  def note(minutes_ago) = { 'name' => 'Kali', 'text' => 'hi', 'created_at' => (NOW - (minutes_ago * 60)).iso8601 }

  def test_a_fresh_note_on_the_wall_smokes
    @notes = [note(30), note(2)]
    assert scenes.scene(at: NOW).smoking
  end

  def test_an_old_note_or_none_does_not
    @notes = [note(10)]
    refute scenes.scene(at: NOW).smoking
    @notes = []
    refute scenes.scene(at: NOW).smoking
  end

  def test_the_central_is_asked_once_a_while
    @notes = [note(1)]
    shared = wall
    3.times { scenes(wall: shared).scene(at: NOW) }
    assert_equal 1, @asked
    assert_equal [note(1)], shared.recent(8)
  end

  def test_only_a_sysop_sees_the_new_feedback
    actor = Rubbs::Common::Central::Actor.new(id: 1, name: 'Tasi')
    assert_equal 3, scenes.scene(sysop: true, actor: actor, at: NOW).mail
    assert_equal 0, scenes.scene(sysop: false, actor: actor, at: NOW).mail
  end
end
