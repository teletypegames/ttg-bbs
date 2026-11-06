# frozen_string_literal: true

require 'time'

# A post of the message boards of before the network's wall (ttg-common
# TTG::Wall), kept as the archive: its board, its stamp (month, day and
# time on the board's clock, no year, the way the boards showed it), the
# writer, the text, and when it was handed over to the wall (+exported_at+).
class PostModel < Rubbs::Common::Storage::Model
  table :posts

  # The title of each board by its id, the prefix of its posts on the wall.
  BOARDS = { 'general' => 'General', 'tech' => 'Tech', 'offtopic' => 'Off-Topic', 'sysop' => 'Sysop' }.freeze

  # Every post with the Time it was written, oldest first: [[post, time], ...].
  # A stamp has no year, so the years come from the order, back from +now+:
  # a post stamped later in the year than the one after it is of the year
  # before.
  def self.dated(now = Time.now)
    after = now
    order(:id).all.reverse.map { |post| [post, after = post.time_before(after)] }.reverse
  end

  # The newest Time of the stamp not after +after+; +after+ itself when the
  # stamp is not one.
  def time_before(after)
    month, day, hour, min = timestamp.to_s.scan(/\d+/).map(&:to_i)
    return after unless min

    time = Time.new(after.year, month, day, hour, min)
    time > after ? Time.new(after.year - 1, month, day, hour, min) : time
  rescue ArgumentError
    after
  end

  # The post as a row of TTG::Wall's import, written at +time+: its board's
  # name before the text.
  def to_wall(time)
    { name: username, text: "[#{BOARDS.fetch(board, board)}] #{text}", created_at: time.utc.iso8601 }
  end
end
