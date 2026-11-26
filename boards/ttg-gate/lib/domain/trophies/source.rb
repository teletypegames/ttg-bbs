# frozen_string_literal: true

module Trophies
  # The numbers of the Trophy Room, fetched with the Today tab's sources
  # (Herald::Service#refresh) into its cache: each part on its own, a part
  # that fails keeps what it had (and is logged), so one Grafana data source
  # down does not blank the room. Every number is of all time; bots,
  # merges and private repositories are left out. The payload:
  #
  #   top:       [{ title, engine, downloads }] the five most downloaded
  #   downloads: { count, visitors }
  #   commits:   { count, repos } of the public repositories
  #   team:      { members, candidates } the Teletypers group of Authentik
  #   ci:        { runs, green } the pipelines of Woodpecker, green a share
  #   catalog:   { released, titles, platforms, categories }
  class Source < Herald::Sources::Source
    KEY   = 'trophies'
    EVERY = 3600
    # A number stays until a newer one comes; this long at most.
    STALE = 90 * 86_400
    # The catalog's counts (WECP).
    FACETS = '/api/software/facets'
    # The parts, in order.
    PARTS = %w[top downloads commits team ci catalog].freeze

    # [grafana] a Trophies::Grafana
    # [catalog] the WarpEngine catalog's address (https://teletypegames.org)
    # [store]   the Herald::Store, for what a failed part had
    def initialize(grafana:, catalog:, store: nil)
      super()
      @grafana = grafana
      @catalog = catalog.to_s.chomp('/')
      @store   = store
    end

    def fetch(_now = Time.now)
      before = @store&.get(KEY)&.payload || {}
      payload = PARTS.to_h { |part| [part, attempt(part) || before[part]] }
      raise Rubbs::Common::Web::HTTP::Error, 'trophies: nothing answered' if payload.values.none?

      payload
    end

    private

    def attempt(part)
      return if part != 'catalog' && !@grafana.configured?

      send(part)
    rescue StandardError => e
      Rubbs.log("trophies #{part}", e, level: :warn)
      nil
    end

    def top
      @grafana.rows(Queries::DOWNLOADS, Queries::TOP_SQL).map { |title, engine, n|
        { 'title' => title.to_s, 'engine' => engine.to_s, 'downloads' => n.to_i }
      }
    end

    def downloads
      count, visitors = @grafana.rows(Queries::DOWNLOADS, Queries::DOWNLOADS_SQL).first
      { 'count' => count.to_i, 'visitors' => visitors.to_i }
    end

    def commits
      count, repos = @grafana.rows(Queries::GITEA, Queries::COMMITS_SQL).first
      { 'count' => count.to_i, 'repos' => repos.to_i }
    end

    def team
      groups = @grafana.rows(Queries::AUTHENTIK, Queries::TEAM_SQL).to_h { |name, n| [name, n.to_i] }
      { 'members' => groups.fetch('Teletypers', 0), 'candidates' => groups.fetch('Jelölt', 0) }
    end

    def ci
      runs  = @grafana.value(Queries::PROMETHEUS, Queries::RUNS_EXPR).to_f
      green = @grafana.value(Queries::PROMETHEUS, Queries::GREEN_EXPR).to_f
      { 'runs' => runs.round, 'green' => runs.positive? ? (green / runs).round(3) : nil }
    end

    def catalog
      facets = get_json("#{@catalog}#{FACETS}")
      {
        'released'   => facets.dig('statuses', 'released').to_i,
        'titles'     => facets['total'].to_i,
        'platforms'  => facets.fetch('platforms', {}).size,
        'categories' => facets.fetch('categories', {}).size
      }
    end
  end
end
