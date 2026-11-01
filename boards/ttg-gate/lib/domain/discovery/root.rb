# frozen_string_literal: true

module Discovery
  # The composition root of Global Discovery: reads the environment and builds
  # the repositories and services once, for the bin/discovery-* commands and
  # the Gate.
  #
  # [TTG_GATE_BBS_DATA]              the data folder (data/)
  # [TTG_GATE_BBS_DISCOVERY_DB]      the catalog (data/discovery.sqlite3)
  # [TTG_GATE_BBS_DISCOVERY_OPTOUT]  the opt-out list (config/discovery-optout.yml)
  # [TTG_GATE_BBS_DISCORD_WEBHOOK]   where import alerts go; empty: nowhere
  # [TTG_GATE_BBS_DIAL_WINDOW]       the Gate's dial limits: the window in
  # [TTG_GATE_BBS_DIAL_PER_CALLER]   seconds, the dials a caller in it, the
  # [TTG_GATE_BBS_DIAL_PER_HOST]     lines to one address at once, the
  # [TTG_GATE_BBS_DIAL_IDLE]         seconds a silent line lasts (DialService)
  class Root
    ROOT = File.expand_path('../../..', __dir__)

    attr_reader :db, :config, :catalog, :probes, :optout, :geoip, :tags, :aliases

    def initialize(env = ENV)
      @data    = env.fetch('TTG_GATE_BBS_DATA', File.join(ROOT, 'data'))
      @db      = Database.new(env.fetch('TTG_GATE_BBS_DISCOVERY_DB', File.join(@data, 'discovery.sqlite3')))
      @config  = ConfigRepository.new(File.join(ROOT, 'config/discovery'))
      @catalog = CatalogRepository.new(@db)
      @probes  = ProbeRepository.new(@db)
      @optout  = OptoutRepository.new(env.fetch('TTG_GATE_BBS_DISCOVERY_OPTOUT',
                                                File.join(ROOT, 'config/discovery-optout.yml')))
      @fetcher = SourceFetcher.new
      @geoip   = GeoipRepository.new(File.join(@data, 'geoip'), fetcher: @fetcher)
      @tags    = TagService.new(@catalog, @probes, @config)
      @aliases = AliasService.new(@catalog)
      @webhook = env['TTG_GATE_BBS_DISCORD_WEBHOOK'].to_s
      @dial_limits = {
        window:     limit(env, 'TTG_GATE_BBS_DIAL_WINDOW', DialService::WINDOW),
        per_caller: limit(env, 'TTG_GATE_BBS_DIAL_PER_CALLER', DialService::PER_CALLER),
        per_host:   limit(env, 'TTG_GATE_BBS_DIAL_PER_HOST', DialService::PER_HOST),
        idle:       limit(env, 'TTG_GATE_BBS_DIAL_IDLE', DialService::IDLE)
      }
    end

    # The Gate's dial limits: window, per_caller, per_host, idle.
    attr_reader :dial_limits

    def importer
      ImportService.new(catalog: @catalog, config: @config, fetcher: @fetcher, tags: @tags, aliases: @aliases,
                        optout: @optout, alert: method(:alert))
    end

    def prober(concurrency: ProberService::CONCURRENCY)
      ProberService.new(catalog: @catalog, probes: @probes, probe: TelnetProbe.new, tags: @tags, aliases: @aliases,
                        optout: @optout, geoip: @geoip, config: @config, metrics: metrics, concurrency: concurrency)
    end

    def metrics
      MetricsService.new(File.join(@data, 'discovery-metrics.prom'), catalog: @catalog, probes: @probes,
                                                                     dials_path: dials_path, db_path: @db.path, history: history,
                                                                     geoip_path: @geoip.path, optout: @optout)
    end

    # The Gate's side: the lists and pages it shows.
    def browse = BrowseService.new(DirectoryRepository.new(@db), @config)

    # The Gate's side: the dial rules, recording each dial as a probe.
    def dials(log: ->(line) { warn line })
      recorder = ProberService.new(catalog: @catalog, probes: @probes, probe: nil, tags: @tags, aliases: @aliases,
                                   optout: @optout, geoip: @geoip, config: @config, log: log)
      DialService.new(recorder: recorder, history: history, live_path: dials_path, log: log, **@dial_limits)
    end

    # The Gate's refused dials and its dials' time and traffic.
    def history = @history ||= DialRepository.new(@db)

    # The Gate's dials in progress (JSON), for the metrics of the prober.
    def dials_path = File.join(@data, 'gate-dials.json')

    def report = ReportService.new(@db)

    # Warns +message+ and posts it to the Discord webhook, when there is one.
    def alert(message)
      warn message
      return if @webhook.empty?

      require 'bbs/discord_webhook'
      hook = BBS::DiscordWebhook.new(@webhook, relay_max: nil, embeds: false, label: 'ttg-gate-bbs-discovery: Discord')
      hook.post(BBS::DiscordWebhook.escape(message))&.join
    end

    private

    # A positive whole number of the environment, else +default+.
    def limit(env, key, default)
      value = env[key].to_s.strip
      return default if value.empty?

      number = Integer(value, 10)
      return number if number.positive?

      warn "ttg-gate-bbs: #{key}=#{value} is not positive, #{default} it is"
      default
    rescue ArgumentError
      warn "ttg-gate-bbs: #{key}=#{value} is not a number, #{default} it is"
      default
    end
  end
end
