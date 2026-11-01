# frozen_string_literal: true

# What the pictures of the clubhouse show of the board at one moment, the
# same for both faces: the nodes behind the windows, whether the chimney
# smokes (a line said in the live chat lately), the caller's unread letters
# (the mailbox flag) and new posts (notes on the cork board), how many sit
# in each door (the lamps of the games room) and on the sofa (the live
# chat), the last names in the guestbook, what is coming up, the wall, and
# the time of day and season (BBS::Season) the pictures are drawn for.
SceneModel = Struct.new(:nodes, :smoking, :mail, :notes, :doors, :sofa, :guestbook, :events, :oneliners,
                        :season, keyword_init: true) do
  def inside = nodes.size

  # Whether node +number+ is taken: a lit window.
  def lit?(number) = nodes.any? { |n| n.number == number }

  # The callers in the door titled +title+.
  def in_door(title) = doors.fetch(title, 0)
end
