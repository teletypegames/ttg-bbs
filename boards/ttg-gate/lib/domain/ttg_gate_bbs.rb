# frozen_string_literal: true

# TTG Gate BBS itself: our own boards from config/boards.yml, Global
# Discovery's catalog, and the accounts of the network (Rubbs::Common::Auth), which
# live here and are asked by the other boards through the API on
# +auth_port+. When the catalog cannot be opened, the gate still dials its
# own boards and says so on the Discovery side.
class TTGGateBBS
  include Rubbs::Common::Board::Domain

  path     :boards,       'config/boards.yml'
  path     :accounts_db,  'data/accounts.sqlite3'
  path     :accounts_metrics, 'data/accounts-metrics.prom'
  setting  :gateway_host, 'host.docker.internal'
  setting  :public_host,  'teletypegames.org'
  setting  :auth_port,    TTG::Auth::PORT
  database :accounts_db, Rubbs::Common::Auth::MIGRATIONS, name: :auth

  service(:accounts) { Rubbs::Common::Auth::Directory.new(store: databases[:auth], roles: TTG::Auth::NEW) }

  background('accounts metrics', every: 120) { AccountsMetrics.new(accounts, accounts_metrics).write }

  service(:directory) { DirectoryService.new(BoardRepository.new(boards, host: gateway_host, public_host: public_host)) }
  service(:browse)    { discovery&.browse }
  service(:dials)     { discovery&.dials }

  # Serves the accounts to the other boards (Rubbs::Common::Auth::API) when there is
  # a port and a secret to sign with. Returns the thread, or +nil+.
  def serve_accounts
    return Rubbs.log('auth', 'no RUBBS_AUTH_SECRET: the accounts API is off', level: :warn) if Rubbs.config.auth_secrets.empty?
    return if auth_port.zero?

    Rubbs::Common::Auth::API.new(accounts, port: auth_port).start
  end

  private

  def discovery
    return @discovery if defined?(@discovery)

    @discovery = Discovery::Root.new(ENV)
  rescue StandardError => e
    Rubbs.log('discovery', "off: #{e.class}: #{e.message}")
    @discovery = nil
  end
end
