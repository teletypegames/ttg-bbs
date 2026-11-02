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
      @optout  = OptoutRepository.new(env.fetch('TTG_GATE_BBS_DISCOVERY_OPTOUT',
                                                File.join(ROOT, 'config/discovery-optout.yml')))
      @webhook = env['TTG_GATE_BBS_DISCORD_WEBHOOK'].to_s
      @dial_limits = DialService::LIMITS.to_h { |key, default| [key, limit(env, "TTG_GATE_BBS_DIAL_#{key.upcase}", default)] }
      build
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
    def dials(log: DialService::LOG)
      recorder = ProbeRecorder.new(catalog: @catalog, probes: @probes, tags: @tags, geoip: @geoip, config: @config)
      DialService.new(recorder: recorder, history: history, live_path: dials_path, log: log, **@dial_limits)
    end

    # The Gate's refused dials and its dials' time and traffic.
    def history = @history ||= DialRepository.new(@db)

    # The Gate's dials in progress (JSON), for the metrics of the prober.
    def dials_path = File.join(@data, 'gate-dials.json')

    def report = ReportService.new(@db)

    # Logs +message+ and posts it to the Discord webhook, when there is one.
    def alert(message)
      BBS.log('import', message)
      return if @webhook.empty?

      require 'bbs/discord_webhook'
      hook = BBS::DiscordWebhook.new(@webhook, relay_max: nil, embeds: false)
      hook.post(BBS::DiscordWebhook.escape(message))&.join
    end

    private

    # The repositories and services on the catalog.
    def build
      @catalog = CatalogRepository.new(@db)
      @probes  = ProbeRepository.new(@db)
      @fetcher = SourceFetcher.new
      @geoip   = GeoipRepository.new(File.join(@data, 'geoip'), fetcher: @fetcher)
      @tags    = TagService.new(@catalog, @probes, @config)
      @aliases = AliasService.new(@catalog)
    end

    # A positive whole number of the environment, else +default+.
    def limit(env, key, default)
      value = env[key].to_s.strip
      return default if value.empty?

      number = Integer(value, 10)
      return number if number.positive?

      BBS.log('config', "#{key}=#{value} is not positive, #{default} it is")
      default
    rescue ArgumentError
      BBS.log('config', "#{key}=#{value} is not a number, #{default} it is")
      default
    end
  end
end
