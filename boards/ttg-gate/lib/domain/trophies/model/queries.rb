# frozen_string_literal: true

module Trophies
  # What the Trophy Room asks Grafana's data sources, as the dashboards
  # count (ttg-downloads, git-gitea-stats, ttg-authentik, ttg-ci): every
  # number of all time; bots, merges and private repositories left out. The
  # tables are not ours: Grafana reads them read-only (grafana_ro).
  module Queries
    # The data sources of Grafana (infra/observability datasources.yaml).
    DOWNLOADS  = 'ttg-downloads-mysql'
    GITEA      = 'gitea-mysql'
    AUTHENTIK  = 'authentik-postgres'
    PROMETHEUS = 'PBFA97CFB590B2093'
    # The queries, as the dashboards count (ttg-downloads, git-gitea-stats,
    # ttg-authentik, ttg-ci).
    TOP_SQL = "SELECT title, engine, COUNT(*) AS n FROM downloads WHERE client_kind <> 'Bot' " \
              'GROUP BY software, title, engine ORDER BY n DESC LIMIT 5'
    DOWNLOADS_SQL = "SELECT COUNT(*), COUNT(DISTINCT visitor) FROM downloads WHERE client_kind <> 'Bot'"
    COMMITS_SQL = 'SELECT COUNT(*), COUNT(DISTINCT c.repo) FROM gitstats.commits c WHERE c.is_merge = 0 AND c.is_bot = 0 ' \
                  "AND c.repo IN (SELECT CONCAT(r.owner_name, '/', r.name) FROM repository r WHERE r.is_private = 0)"
    TEAM_SQL = 'SELECT g.name, COUNT(*) FROM authentik_core_user u ' \
               'JOIN authentik_core_user_groups ug ON ug.user_id = u.id ' \
               'JOIN authentik_core_group g ON g.group_uuid = ug.group_id ' \
               "WHERE g.name IN ('Teletypers', 'Jelölt') AND u.is_active GROUP BY g.name"
    RUNS_EXPR  = 'sum(vps_ci_pipelines_total)'
    GREEN_EXPR = 'sum(vps_ci_pipelines_total{status="success"})'
  end
end
