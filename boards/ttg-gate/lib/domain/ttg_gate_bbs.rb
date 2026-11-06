# frozen_string_literal: true

# TTG Gate BBS itself: our own boards from config/boards.yml, Global
# Discovery's catalog, and the network's Central (Rubbs::Common::Central): the
# accounts (Rubbs::Common::Auth) live here and the other boards ask them on
# +central_port+. When the catalog cannot be opened, the gate still dials its
# own boards and says so on the Discovery side.
class TTGGateBBS
  include Rubbs::Common::Board::Domain

  path     :boards,       'config/boards.yml'
  path     :accounts_db,  'data/accounts.sqlite3'
  path     :accounts_metrics, 'data/accounts-metrics.prom'
  setting  :gateway_host, 'host.docker.internal'
  setting  :public_host,  'teletypegames.org'
  setting  :central_port, TTG::Central::PORT
  database :accounts_db, Rubbs::Common::Auth::MIGRATIONS, name: :auth

  service(:accounts) { Rubbs::Common::Auth::Directory.new(store: databases[:auth], roles: TTG::Auth::NEW) }

  background('accounts metrics', every: 120) do
    AccountsMetrics.new(accounts, accounts_metrics, services: Rubbs.config.central&.server&.services).write
  end

  service(:directory) { DirectoryService.new(BoardRepository.new(boards, host: gateway_host, public_host: public_host)) }
  service(:browse)    { discovery&.browse }
  service(:dials)     { discovery&.dials }

  private

  def discovery
    return @discovery if defined?(@discovery)

    @discovery = Discovery::Root.new(ENV)
  rescue StandardError => e
    Rubbs.log('discovery', "off: #{e.class}: #{e.message}")
    @discovery = nil
  end
end
