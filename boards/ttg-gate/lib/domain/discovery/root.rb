# frozen_string_literal: true

module Discovery
  # The composition root of Global Discovery: reads the environment, opens
  # the catalog (migrated by DISCOVERY_MIGRATIONS, its models bound) and
  # builds the repositories and services once, for the bin/discovery-*
  # commands and the Gate, which do not share a Rubbs::Common::Board::Domain.
  #
  # [TTG_GATE_BBS_DATA]              the data folder (data/)
  # [TTG_GATE_BBS_DISCOVERY_DB]      the catalog (data/discovery.sqlite3)
  # [TTG_GATE_BBS_DISCOVERY_OPTOUT]  the opt-out list (config/discovery-optout.yml)
  # [TTG_GATE_BBS_OPS_WEBHOOK]       where import alerts go (an ops alert, the only Discord line
  #                                  besides TTG::Feedback); empty: nowhere. The older name
  #                                  TTG_GATE_BBS_DISCORD_WEBHOOK is still read
  # [TTG_GATE_BBS_DIAL_WINDOW]       the Gate's dial limits: the window in
  # [TTG_GATE_BBS_DIAL_PER_CALLER]   seconds, the dials a caller in it, the
  # [TTG_GATE_BBS_DIAL_PER_HOST]     lines to one address at once, the
  # [TTG_GATE_BBS_DIAL_IDLE]         seconds a silent line lasts (DialService)
  class Root
    ROOT = File.expand_path('../../..', __dir__)

    # The name of the catalog's database: its models say
    # <tt>table :x, database: :discovery</tt>.
    DATABASE = :discovery

    attr_reader :db, :db_path, :config, :optout, :geoip, :tags, :aliases

    def initialize(env = ENV)
      @data    = env.fetch('TTG_GATE_BBS_DATA', File.join(ROOT, 'data'))
      @db_path = env.fetch('TTG_GATE_BBS_DISCOVERY_DB', File.join(@data, 'discovery.sqlite3'))
      @db      = Root.open(@db_path)
      @config  = ConfigRepository.new(File.join(ROOT, 'config/discovery'))
      @optout  = OptoutRepository.new(env.fetch(
                                        'TTG_GATE_BBS_DISCOVERY_OPTOUT',
                                        File.join(ROOT, 'config/discovery-optout.yml')
                                      ))
      @webhook = (env['TTG_GATE_BBS_OPS_WEBHOOK'] || env['TTG_GATE_BBS_DISCORD_WEBHOOK']).to_s
      @dial_limits = DialService::LIMITS.to_h { |key, default| [key, limit(env, "TTG_GATE_BBS_DIAL_#{key.upcase}", default)] }
      build
    end

    # The Gate's dial limits: window, per_caller, per_host, idle.
    attr_reader :dial_limits

    # The catalog at +path+, made or migrated (DISCOVERY_MIGRATIONS), the
    # models of DATABASE bound to it. A write transaction takes the write
    # lock at once (BEGIN IMMEDIATE): the importer, the prober and the Gate
    # write the one file.
    def self.open(path)
      db = Rubbs::Common::Storage::Database.open(path, DISCOVERY_MIGRATIONS)
      db.transaction_mode = :immediate
      Rubbs::Common::Storage::Model.bind(DATABASE => db)
      db
    end

    def importer
      ImportService.new(
        config:  @config,
        fetcher: @fetcher,
        tags:    @tags,
        aliases: @aliases,
        optout:  @optout,
        alert:   method(:alert)
      )
    end

    def prober(concurrency: ProberService::CONCURRENCY)
      ProberService.new(
        probe:       TelnetProbe.new,
        tags:        @tags,
        aliases:     @aliases,
        optout:      @optout,
        geoip:       @geoip,
        config:      @config,
        metrics:     metrics,
        concurrency: concurrency
      )
    end

    def metrics
      MetricsService.new(
        File.join(@data, 'discovery-metrics.prom'),
        dials_path: dials_path,
        db_path:    @db_path,
        history:    history,
        geoip_path: @geoip.path,
        optout:     @optout
      )
    end

    # The Gate's side: the lists and pages it shows.
    def browse = BrowseService.new(@config)

    # The Gate's side: the dial rules, recording each dial as a probe.
    def dials(log: DialService::LOG)
      recorder = ProbeRecorder.new(tags: @tags, geoip: @geoip, config: @config)
      DialService.new(recorder: recorder, history: history, live_path: dials_path, log: log, **@dial_limits)
    end

    # The Gate's refused dials and its dials' time and traffic.
    def history = @history ||= DialHistoryService.new

    # The Gate's dials in progress (JSON), for the metrics of the prober.
    def dials_path = File.join(@data, 'gate-dials.json')

    def report = ReportService.new

    # Logs +message+ and posts it to the Discord webhook, when there is one.
    def alert(message)
      Rubbs.log('import', message)
      return if @webhook.empty?

      require 'rubbs/common/web/discord_webhook'
      hook = Rubbs::Common::Web::DiscordWebhook.new(@webhook, relay_max: nil, embeds: false)
      hook.post(Rubbs::Common::Web::DiscordWebhook.escape(message))&.join
    end

    private

    # The repositories and services on the catalog.
    def build
      @fetcher = SourceFetcher.new
      @geoip   = GeoipRepository.new(File.join(@data, 'geoip'), fetcher: @fetcher)
      @tags    = TagService.new(@config)
      @aliases = AliasService.new
    end

    # A positive whole number of the environment, else +default+.
    def limit(env, key, default)
      value = env[key].to_s.strip
      return default if value.empty?

      number = Integer(value, 10)
      return number if number.positive?

      Rubbs.log('config', "#{key}=#{value} is not positive, #{default} it is")
      default
    rescue ArgumentError
      Rubbs.log('config', "#{key}=#{value} is not a number, #{default} it is")
      default
    end
  end
end
