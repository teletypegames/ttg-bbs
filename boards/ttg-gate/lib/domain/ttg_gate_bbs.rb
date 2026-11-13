# frozen_string_literal: true

# TTG Gate BBS itself: our own boards from config/boards.yml, Global
# Discovery's catalog, and the network's Central (Rubbs::Common::Central): the
# accounts (Rubbs::Common::Auth) live here and the other boards ask them on
# +central_port+. When the catalog cannot be opened, the gate still dials its
# own boards and says so on the Discovery side. The Today tab (Herald) reads
# a cache the background fills; #today makes a caller's page of it.
class TTGGateBBS
  include Rubbs::Common::Board::Domain

  path     :boards,       'config/boards.yml'
  path     :accounts_db,  'data/accounts.sqlite3'
  path     :accounts_metrics, 'data/accounts-metrics.prom'
  setting  :gateway_host, 'host.docker.internal'
  setting  :public_host,  'teletypegames.org'
  setting  :central_port, TTG::Central::PORT
  setting  :local_host,   '127.0.0.1'
  path     :herald_db,    'data/herald.sqlite3'
  path     :herald_notes, '../*/data/herald.json'
  setting  :herald_fetch, true
  database :accounts_db, Rubbs::Common::Auth::MIGRATIONS, name: :auth
  database :herald_db,   HERALD_MIGRATIONS, name: :herald

  service(:accounts) { Rubbs::Common::Auth::Directory.new(store: databases[:auth], roles: TTG::Auth::NEW) }

  background('accounts metrics', every: 120) do
    AccountsMetrics.new(accounts, accounts_metrics, services: Rubbs.config.central&.server&.services, herald: herald).write
  end

  service(:directory) do
    DirectoryService.new(BoardRepository.new(boards, host: gateway_host, public_host: public_host, local_host: local_host))
  end
  service(:browse)    { discovery&.browse }
  service(:dials)     { discovery&.dials }
  service(:herald)    { Herald::Service.new(store: Herald::Store.new) }

  background('herald', every: 600, if: -> { herald_fetch }) { herald.refresh }

  # Seconds the network part of the Today tab is kept before it is counted
  # again.
  NETWORK_TTL = 60
  # The lock of the network part's count.
  NETWORK_LOCK = Mutex.new

  # The Today tab's page (a Herald::Edition) for the caller from +ip+: the
  # weather of their country's capital beside Budapest's.
  def today(ip: nil, at: Time.now)
    herald.edition(country: discovery&.geoip&.country(ip), network: network(at), at: at)
  end

  private

  def network(at)
    NETWORK_LOCK.synchronize do
      if @network.nil? || at.to_i - @network_at >= NETWORK_TTL
        @network_at = at.to_i
        @network    = count_network(at)
      end
      @network
    end
  end

  def count_network(at)
    online = browse ? browse.all(state: 'online') : []
    Herald::Network.new(
      callers:      Rubbs.calls.size,
      boards:       directory.boards.size,
      walls:        newest_walls,
      online:       online.size,
      fresh:        browse ? browse.new_this_week.size : 0,
      board_of_day: board_of_day(online.select(&:petscii?), at),
      ours:         ours_of_day(directory.boards, at),
      notes:        board_notes(at)
    )
  end

  # The notes our boards keep for the Today tab, each with the name of its board.
  def board_notes(at)
    names = directory.boards.to_h { |b| [b.id, b.name] }
    Herald::Notes.new(herald_notes).current(at).filter_map { |n| names[n.board] && [names[n.board], n] }
  end

  # One of our own boards, a different one each day, with its number in
  # Own Servers: the quieter boards get their turn on the Today page.
  def ours_of_day(boards, at)
    return if boards.empty?

    index = (Herald.local(at).to_date.jd * 5) % boards.size
    [index + 1, boards[index]]
  end

  # An online PETSCII board, the same one all day: the day picks it.
  def board_of_day(boards, at)
    return if boards.empty?

    boards.sort_by(&:id)[Herald.local(at).to_date.jd % boards.size]
  end

  def newest_walls
    TTG::Wall.lines(2, board: nil)
  rescue StandardError => e
    Rubbs.log('herald walls', e, level: :warn)
    []
  end

  def discovery
    return @discovery if defined?(@discovery)

    @discovery = Discovery::Root.new(ENV)
  rescue StandardError => e
    Rubbs.log('discovery', "off: #{e.class}: #{e.message}")
    @discovery = nil
  end
end
