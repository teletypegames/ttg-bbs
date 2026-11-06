# frozen_string_literal: true

require 'json'
require 'time'

# What the callers left before the network's wall and feedback (ttg-common
# TTG::Wall and TTG::Feedback, on TTG Gate BBS), handed over to them once:
# the posts of the message boards and the oneliners to this board's wall,
# in the order they were written, a post with its board's name before it
# ("[Tech] …"); the letters to the Sysop box to the feedback, read already.
# The letters between names are not handed over: they stay in the database
# with the rest, as the archive. A row handed over is marked (+exported_at+),
# so a run hands over only what is left, and the one after the last nothing.
class ExportService
  # Rows in one request at most, and their bytes as JSON: the Central takes
  # 16 KB a request.
  BATCH = 20
  BYTES = 12_000

  # +stamp+ (a time as the board wrote it) as ISO 8601 in UTC; +nil+ when it
  # is not a time.
  def self.utc(stamp)
    Time.parse(stamp.to_s).utc.iso8601
  rescue ArgumentError
    nil
  end

  # The handing over to +wall+ and +feedback+ (Rubbs::Common::Central::Proxy
  # each, by default the network's), the years of the posts' stamps counted
  # back from +now+.
  def initialize(wall: TTG::Wall.walls, feedback: TTG::Feedback.box, now: Time.now)
    @wall     = wall
    @feedback = feedback
    @now      = now
  end

  # Hands over what is left; raises when the Central does not take it (the
  # background job tries again), keeping what went before marked. Returns
  # the counts, <tt>{ wall:, feedback: }</tt>.
  def call
    counts = { wall: hand_over(@wall, wall_rows), feedback: hand_over(@feedback, feedback_rows) }
    Rubbs.log('export', 'handed over', **counts) if counts.values.any?(&:positive?)
    counts
  end

  private

  # [[record, row], ...] of the posts and the oneliners, oldest first.
  def wall_rows
    posts = PostModel.dated(@now).reject { |post, _| post.exported_at }.map { |post, time| [post, post.to_wall(time)] }
    lines = OnelinerModel.unexported.map { |line| [line, line.to_wall] }
    (posts + lines).each_with_index.sort_by { |(_, row), i| [row[:created_at].to_s, i] }.map(&:first)
  end

  def feedback_rows = LetterModel.unexported_to_sysop.map { |letter| [letter, letter.to_feedback] }

  # Sends +rows+ to +service+'s import a batch at a time, each batch marked
  # once it is taken. Returns how many went.
  def hand_over(service, rows)
    batches(rows).sum do |batch|
      answer = service.call(:import, nil, rows: batch.map(&:last))
      raise "the Central did not take them: #{answer['result']}" unless answer['result'] == 'ok'

      stamp = Time.now.utc.iso8601
      batch.map(&:first).each { |record| record.this.update(exported_at: stamp) }
      batch.size
    end
  end

  # +rows+ cut into batches of BATCH rows and BYTES at most.
  def batches(rows)
    rows.each_with_object([[]]) do |row, list|
      full = list.last.size >= BATCH || (list.last.any? && bytes(list.last + [row]) > BYTES)
      list << [] if full
      list.last << row
    end.reject(&:empty?)
  end

  def bytes(rows) = JSON.generate(rows.map(&:last)).bytesize
end
