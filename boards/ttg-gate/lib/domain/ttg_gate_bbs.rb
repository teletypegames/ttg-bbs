# frozen_string_literal: true

# The composition root of TTG Gate BBS: reads the environment and builds the
# repositories and services once; both faces work on the one instance. When
# Global Discovery's catalog cannot be opened, the gate still dials its own
# boards and says so on the Discovery side.
class TTGGateBBS
  ROOT = File.expand_path('../..', __dir__)

  attr_reader :directory

  def initialize(env = ENV)
    boards = BoardRepository.new(
      env.fetch('TTG_GATE_BBS_BOARDS', File.join(ROOT, 'config/boards.yml')),
      host:        env.fetch('TTG_GATE_BBS_GATEWAY_HOST', 'host.docker.internal'),
      public_host: env.fetch('TTG_GATE_BBS_PUBLIC_HOST', 'teletypegames.org')
    )
    @directory = DirectoryService.new(boards)
    open_discovery(env)
  end

  # Global Discovery's lists and pages (Discovery::BrowseService), nil
  # without a catalog.
  attr_reader :browse

  # Global Discovery's dial rules and records (Discovery::DialService), nil
  # without a catalog.
  attr_reader :dials

  def services = { directory: @directory, browse: @browse, dials: @dials }

  private

  def open_discovery(env)
    root = Discovery::Root.new(env)
    @browse = root.browse
    @dials  = root.dials(log: ->(line) { $stdout.puts(line) })
  rescue StandardError => e
    warn "ttg-gate-bbs: Global Discovery is off: #{e.class}: #{e.message}"
    @browse = @dials = nil
  end
end
