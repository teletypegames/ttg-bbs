# frozen_string_literal: true

# Monitor BBS itself, whatever terminal a caller has: Grafana's dashboards
# read through its API with a service account's token (MONITOR_BBS_GRAFANA_TOKEN,
# the Viewer role is enough) and drawn as text. It keeps no data of its own.
# Only callers with the ROLE come in (UI::Monitor.run checks it).
class MonitorBBS
  include Rubbs::Common::Board::Domain

  # The role a caller needs.
  ROLE = 'grafana'

  setting :grafana_url, 'http://grafana:3000'
  setting :grafana_token, ''

  service(:grafana) { MonitorService.new(Grafana::Client.new(url: grafana_url, token: grafana_token)) }

  # Begins the board; says in the log when Grafana's token is missing (the
  # board answers, and tells its callers the same).
  def start
    Rubbs.log('monitor', 'MONITOR_BBS_GRAFANA_TOKEN is not set: no dashboard can be read') if grafana_token.to_s.empty?
    super
  end
end
