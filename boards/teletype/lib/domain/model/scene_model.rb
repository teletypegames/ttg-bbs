# frozen_string_literal: true

# What the pictures of the clubhouse show of the board at one moment, the
# same for both faces: the nodes behind the windows, whether the chimney
# smokes (a note written on the wall lately), the new feedback waiting
# for a sysop (the mailbox flag; 0 for anyone else), how many sit in each
# door (the lamps of the games room), the last names in the guestbook,
# what is coming up, the newest notes of the wall (TTG::Wall.lines: Hashes
# with String keys), and the time of day and season
# (Rubbs::Common::Season) the pictures are drawn for.
SceneModel = Struct.new(
  :nodes,
  :smoking,
  :mail,
  :doors,
  :guestbook,
  :events,
  :wall,
  :season,
  keyword_init: true
) do
  def inside = nodes.size

  # Whether node +number+ is taken: a lit window.
  def lit?(number) = nodes.any? { |n| n.number == number }

  # The callers in the door titled +title+.
  def in_door(title) = doors.fetch(title, 0)
end
