# frozen_string_literal: true

module Discovery
  # The composition root of Global Discovery: reads the environment and builds
  # the repositories and services once, for the bin/discovery-* commands.
  #
  # [TTG_GATE_BBS_DATA]              the data folder (data/)
  # [TTG_GATE_BBS_DISCOVERY_DB]      the catalog (data/discovery.sqlite3)
  # [TTG_GATE_BBS_DISCOVERY_OPTOUT]  the opt-out list (config/discovery-optout.yml)
  # [TTG_GATE_BBS_DISCORD_WEBHOOK]   where import alerts go; empty: nowhere
  class Root
    ROOT = File.expand_path('../../..', __dir__)

    attr_reader :db, :config, :catalog, :probes, :optout, :tags, :aliases

    def initialize(env = ENV)
      @data    = env.fetch('TTG_GATE_BBS_DATA', File.join(ROOT, 'data'))
      @db      = Database.new(env.fetch('TTG_GATE_BBS_DISCOVERY_DB', File.join(@data, 'discovery.sqlite3')))
      @config  = ConfigRepository.new(File.join(ROOT, 'config/discovery'))
      @catalog = CatalogRepository.new(@db)
      @probes  = ProbeRepository.new(@db)
      @optout  = OptoutRepository.new(env.fetch('TTG_GATE_BBS_DISCOVERY_OPTOUT',
                                                File.join(ROOT, 'config/discovery-optout.yml')))
      @fetcher = SourceFetcher.new
      @tags    = TagService.new(@catalog, @probes, @config)
      @aliases = AliasService.new(@catalog)
      @webhook = env['TTG_GATE_BBS_DISCORD_WEBHOOK'].to_s
    end

    def importer
      ImportService.new(catalog: @catalog, config: @config, fetcher: @fetcher, tags: @tags, aliases: @aliases,
                        optout: @optout, alert: method(:alert))
    end

    def report = ReportService.new(@db)

    # Warns +message+ and posts it to the Discord webhook, when there is one.
    def alert(message)
      warn message
      return if @webhook.empty?

      require 'bbs/discord_webhook'
      hook = BBS::DiscordWebhook.new(@webhook, relay_max: nil, embeds: false, label: 'ttg-gate-bbs-discovery: Discord')
      hook.post(BBS::DiscordWebhook.escape(message))&.join
    end
  end
end
