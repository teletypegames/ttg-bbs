# frozen_string_literal: true

# The composition root of TTG Gate BBS: reads the environment and builds the
# repository and the service once; both faces work on the one instance.
class TTGGateBBS
  ROOT = File.expand_path('../..', __dir__)

  attr_reader :directory

  def initialize
    boards = BoardRepository.new(
      ENV.fetch('TTG_GATE_BBS_BOARDS', File.join(ROOT, 'config/boards.yml')),
      host:        ENV.fetch('TTG_GATE_BBS_GATEWAY_HOST', 'host.docker.internal'),
      public_host: ENV.fetch('TTG_GATE_BBS_PUBLIC_HOST', 'teletypegames.org')
    )
    @directory = DirectoryService.new(boards)
  end

  def services = { directory: @directory }
end
