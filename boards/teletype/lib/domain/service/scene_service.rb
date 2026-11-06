# frozen_string_literal: true

# The live elements of the clubhouse pictures (SceneModel), gathered from
# the board's own services and its wall on the network's Central: nothing
# else is asked of the outside world.
class SceneService
  # A note on the wall this recently makes the chimney smoke.
  SMOKE_SECONDS = 300
  # The notes the graffiti wall runs.
  WALL_NOTES = 8

  def initialize(online:, wall:, feedback:, last_callers:, site:, door_titles:)
    @online       = online
    @wall         = wall
    @feedback     = feedback
    @last_callers = last_callers
    @site         = site
    @door_titles  = door_titles
  end

  # The scene at +at+; the mailbox counts the new feedback for a +sysop+
  # (+actor+, a Rubbs::Common::Central::Actor, asks for it).
  def scene(sysop: false, actor: nil, at: Time.now)
    nodes = @online.nodes
    SceneModel.new(
      nodes:     nodes,
      smoking:   smoking?(at),
      mail:      sysop && actor ? @feedback.new_count(actor) : 0,
      doors:     doors(nodes),
      guestbook: @last_callers.recent(3),
      events:    @site.upcoming_events(2),
      wall:      @wall.recent(WALL_NOTES),
      season:    Rubbs::Common::Season.now(at: at, jam: @site.jam(at.to_date))
    )
  end

  private

  def smoking?(at)
    written = @wall.written_at
    !written.nil? && at - written <= SMOKE_SECONDS
  end

  # {door title => callers inside}, from the nodes' activity ("Door: SERMO").
  def doors(nodes)
    @door_titles.to_h do |title|
      [title, nodes.count { |n| n.activity.to_s.start_with?("Door: #{title}") }]
    end
  end
end
