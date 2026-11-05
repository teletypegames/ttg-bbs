# frozen_string_literal: true

# The live elements of the clubhouse pictures (SceneModel), gathered from
# the board's own services: nothing is asked of the outside world.
class SceneService
  # A line in the live chat this recently makes the chimney smoke.
  SMOKE_SECONDS = 60
  # How far back a post counts as a new note for a caller without a name.
  NOTE_DAYS = 7

  def initialize(online:, chat:, boards:, mail:, last_callers:, site:, oneliners:, door_titles:)
    @online       = online
    @chat         = chat
    @boards       = boards
    @mail         = mail
    @last_callers = last_callers
    @site         = site
    @oneliners    = oneliners
    @door_titles  = door_titles
  end

  # The scene as +name+ sees it: their mail and new notes when +registered+.
  def scene(name, registered:, sysop: false, at: Time.now)
    nodes = @online.nodes
    SceneModel.new(
      nodes:     nodes,
      smoking:   smoking?(at),
      mail:      registered ? @mail.unread_count(name, sysop: sysop) : 0,
      notes:     registered ? @boards.new_scan(name).values.sum : recent_notes(at),
      doors:     doors(nodes),
      sofa:      nodes.count { |n| n.activity.to_s.match?(/live chat/i) },
      guestbook: @last_callers.recent(3),
      events:    @site.upcoming_events(2),
      oneliners: @oneliners.recent(8),
      season:    Rubbs::Common::Season.now(at: at, jam: @site.jam(at.to_date))
    )
  end

  private

  def smoking?(at)
    said = @chat.said_at
    !said.nil? && at - said <= SMOKE_SECONDS
  end

  # {door title => callers inside}, from the nodes' activity ("Door: SERMO").
  def doors(nodes)
    @door_titles.to_h do |title|
      [title, nodes.count { |n| n.activity.to_s.start_with?("Door: #{title}") }]
    end
  end

  # The posts of the last NOTE_DAYS days; a stamp is month, day and time.
  def recent_notes(at)
    since = (at - (NOTE_DAYS * 86_400)).strftime('%m-%d')
    today = at.strftime('%m-%d')
    @boards.latest(50).count do |_, m|
      stamp = m.timestamp.to_s[0, 5]
      since <= today ? stamp.between?(since, today) : (stamp >= since || stamp <= today)
    end
  end
end
