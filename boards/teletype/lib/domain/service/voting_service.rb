# frozen_string_literal: true

require 'yaml'

# The Voting Booth: the polls of lib/content/polls.yml, the catalog's games
# and the board's doors filling the dynamic ones.
class VotingService
  Poll = Struct.new(:id, :title, :question, :options)

  def initialize(repo, path:, games:, doors: [])
    @repo  = repo
    @path  = path
    @games = games
    @doors = doors
  end

  def polls
    YAML.safe_load_file(@path).map do |p|
      Poll.new(p['id'], p['title'] || p['question'], p['question'], options_for(p['options']))
    end
  rescue StandardError => e
    warn "VotingService: #{e.class}: #{e.message}"
    []
  end

  def ballot(poll, username) = @repo.ballot(poll.id, username)

  # [[option, votes], ...] in the poll's order, plus any option that has
  # votes but left the list (a game renamed).
  def results(poll)
    tally = @repo.tally(poll.id)
    (poll.options | tally.keys).map { |o| [o, tally[o] || 0] }
  end

  def total(poll) = @repo.tally(poll.id).values.sum

  def vote(poll, username, option)
    return :anonymous if username.to_s.casecmp?(AccountService::ANONYMOUS)
    return :unknown unless poll.options.include?(option)

    @repo.cast(poll.id, username, option)
    :ok
  end

  private

  def options_for(spec)
    case spec
    when 'catalog' then @games.all.select { |g| g.released? && !g.dev_build? }.map(&:title).uniq.sort
    when 'doors'   then @doors
    else Array(spec).map(&:to_s)
    end
  end
end
