# frozen_string_literal: true

require 'csv'
require 'time'
require 'fileutils'

# The ballots of the Voting Booth: one per poll and name, kept by the
# chosen option's text. A name that votes again changes its ballot.
class VoteRepository
  def initialize(path)
    @path  = path
    @mu    = Mutex.new
    @votes = load
  end

  def cast(poll_id, username, option)
    @mu.synchronize do
      (@votes[poll_id] ||= {})[username.downcase] = option
      FileUtils.mkdir_p(File.dirname(@path))
      CSV.open(@path, 'a') { |csv| csv << [poll_id, username.downcase, option, Time.now.iso8601] }
    end
  end

  def ballot(poll_id, username)
    @mu.synchronize { @votes.dig(poll_id, username.to_s.downcase) }
  end

  # {option => votes}
  def tally(poll_id)
    @mu.synchronize { (@votes[poll_id] || {}).values.tally }
  end

  private

  # The file is a log: a later row of the same poll and name wins.
  def load
    return {} unless File.exist?(@path)
    raw = File.binread(@path).force_encoding(Encoding::UTF_8).scrub
    CSV.parse(raw).each_with_object({}) do |(poll, name, option), votes|
      (votes[poll] ||= {})[name] = option if poll && name && option
    end
  rescue StandardError
    {}
  end
end
