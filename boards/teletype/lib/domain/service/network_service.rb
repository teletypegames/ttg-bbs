# frozen_string_literal: true

# The Teletype Games BBS Network: where each kind of thing has its board,
# the town around the clubhouse.
class NetworkService
  def initialize(repo)
    @clubhouse = repo.clubhouse
    @boards    = repo.boards
  end

  attr_reader :clubhouse

  # The other boards, in the order of the town map.
  attr_reader :boards

  # Every board, this one first, then by port: the lists of the network.
  def all = [@clubhouse, *@boards.sort_by(&:port)]
end
