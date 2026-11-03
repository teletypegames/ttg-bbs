# frozen_string_literal: true

# TTG Gate BBS itself: our own boards from config/boards.yml and Global
# Discovery's catalog. When the catalog cannot be opened, the gate still
# dials its own boards and says so on the Discovery side.
class TTGGateBBS
  include BBS::Domain

  path    :boards,       'config/boards.yml'
  setting :gateway_host, 'host.docker.internal'
  setting :public_host,  'teletypegames.org'

  service(:directory) { DirectoryService.new(BoardRepository.new(boards, host: gateway_host, public_host: public_host)) }
  service(:browse)    { discovery&.browse }
  service(:dials)     { discovery&.dials }

  private

  def discovery
    return @discovery if defined?(@discovery)

    @discovery = Discovery::Root.new(ENV)
  rescue StandardError => e
    BBS.log('discovery', "off: #{e.class}: #{e.message}")
    @discovery = nil
  end
end
