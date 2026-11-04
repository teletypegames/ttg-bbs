# frozen_string_literal: true

require 'yaml'
require 'bbs/check'
require_relative 'sync'

module TTG
  # The house rules of the Teletype Games boards, added to BBS::Check: the
  # names, the files every board has, the Dockerfile, .dockerignore and
  # pipeline of TTG::Sync, the shared RuboCop rules, the limits and stop time
  # of the compose service, the preset, and every setting of the domain in
  # env-example.
  module Check
    # The files of a TTG board beside rubbs' own.
    FILES = %w[Dockerfile compose.yaml .dockerignore .rubocop.yml .woodpecker.yaml LICENSE env-example].freeze
    # What a compose service sets for itself.
    COMPOSE_KEYS = %w[container_name mem_limit cpus pids_limit restart].freeze
    # The telnet ports of the boards.
    PORTS = 2300..2399
    # What only the board's own service sets: the time it gets to stop in
    # order (rubbs tells its callers and waits BBS_SHUTDOWN_SECONDS).
    BOARD_KEYS = %w[stop_grace_period].freeze
    # The label docker-autoheal restarts an unhealthy container by.
    AUTOHEAL = 'org.teletypegames.autoheal'
    # The shared RuboCop rules a board's .rubocop.yml inherits.
    RUBOCOP = %r{^inherit_gem:\s*\n\s+ttg-common:\s+lib/ttg/board/rubocop\.yml\s*$}

    BBS::Check.rule(:ttg_name, 'the technical name is <slug>-bbs, the folder too') do |board|
      slug = board.slug
      next board.fail('bbs.rb', 'no BBS.board title') unless slug

      board.fail('bbs.rb', "the technical name #{slug} does not end with -bbs") unless slug.end_with?('-bbs')
      folder = File.basename(board.root)
      board.fail('.', "the folder #{folder} is not #{slug}") unless folder == slug
    end

    BBS::Check.rule(:ttg_files, 'the files of a TTG board') do |board|
      FILES.each { |path| board.fail(path, 'missing') unless board.file?(path) }
    end

    BBS::Check.rule(:ttg_preset, 'bbs.rb uses the TTG preset') do |board|
      text = board.read('bbs.rb').to_s
      board.fail('bbs.rb', "no require 'ttg/common'") unless text.include?("require 'ttg/common'")
      board.fail('bbs.rb', 'no preset TTG::PRESET') unless text.match?(/^\s*preset\s+TTG::PRESET\b/)
    end

    BBS::Check.rule(:ttg_docker, 'the Dockerfile and .dockerignore of every TTG board (rake ttg:sync)') do |board|
      dockerfile = board.read('Dockerfile')
      if dockerfile && dockerfile != Sync.dockerfile(dockerfile)
        board.fail('Dockerfile', 'differs from ttg-common lib/ttg/board/Dockerfile (only packages may be added): rake ttg:sync')
      end
      ignore = board.read('.dockerignore')
      if ignore && ignore != Sync::DOCKERIGNORE
        board.fail('.dockerignore', 'differs from ttg-common lib/ttg/board/dockerignore: rake ttg:sync')
      end
    end

    BBS::Check.rule(:ttg_rubocop, '.rubocop.yml inherits the shared rules of ttg-common') do |board|
      text = board.read('.rubocop.yml')
      board.fail('.rubocop.yml', 'no inherit_gem: ttg-common: lib/ttg/board/rubocop.yml') if text && !text.match?(RUBOCOP)
    end

    BBS::Check.rule(:ttg_compose, 'compose.yaml: the board service with its limits and one telnet port') do |board|
      text = board.read('compose.yaml')
      next unless text

      services = YAML.safe_load(text).fetch('services', {})
      main = services[board.slug]
      next board.fail('compose.yaml', "no service #{board.slug}") unless main

      services.each do |name, service|
        COMPOSE_KEYS.each { |key| board.fail('compose.yaml', "#{name}: no #{key}") unless service.key?(key) }
        board.fail('compose.yaml', "#{name}: container_name is not #{name}") unless service['container_name'] == name
        board.fail('compose.yaml', "#{name}: restart is not unless-stopped") unless service['restart'] == 'unless-stopped'
      end
      BOARD_KEYS.each { |key| board.fail('compose.yaml', "#{board.slug}: no #{key}") unless main.key?(key) }
      ports = Array(main['ports']).map { |p| p.to_s.split(':') }
      ok = ports.size == 1 && PORTS.cover?(ports[0][0].to_i) && ports[0][1] == '2323'
      board.fail('compose.yaml', "#{board.slug}: one port, 23xx:2323") unless ok
      services.except(board.slug).each do |name, service|
        board.fail('compose.yaml', "#{name}: only the board service has a port") if service['ports']
        next unless service['build']

        board.fail('compose.yaml', "#{name}: healthcheck: { disable: true } (the image's asks the board's port)") unless
          service.dig('healthcheck', 'disable') == true
        board.fail('compose.yaml', "#{name}: label org.teletypegames.autoheal: \"false\"") unless
          service.dig('labels', AUTOHEAL).to_s == 'false'
      end
    end

    BBS::Check.rule(:ttg_ci, 'the pipeline of ttg-common lib/ttg/board/woodpecker.yaml.erb (rake ttg:sync)') do |board|
      text = board.read('.woodpecker.yaml')
      next unless text && board.slug

      wanted = Sync.woodpecker(board.slug, Sync.port(board))
      board.fail('.woodpecker.yaml', 'differs from the ttg-common template: rake ttg:sync') unless text == wanted
    end

    BBS::Check.rule(:ttg_auth, 'a board with accounts lists RUBBS_AUTH_SECRET in env-example') do |board|
      next unless board.read('bbs.rb').to_s.match?(/^\s*auth\b/)

      example = board.read('env-example').to_s
      board.fail('env-example', 'no RUBBS_AUTH_SECRET (the board has auth)') unless example.match?(/^#?\s*RUBBS_AUTH_SECRET=/)
    end

    BBS::Check.rule(:ttg_env, 'env-example lists every setting of the domain') do |board|
      example = board.read('env-example')
      domain  = board.declaration[:domain]
      next unless example && domain && board.file?('lib/domain.rb')

      BBS.config.env_prefix = board.env_prefix
      begin
        require File.join(board.root, 'lib/domain')
        klass = Object.const_get(domain)
      rescue LoadError, StandardError => e
        next board.fail('lib/domain.rb', "could not load #{domain}: #{e.class}: #{e.message}")
      end
      next unless klass.respond_to?(:environment_variables)

      klass.environment_variables.reject { |name| example.match?(/^#?\s*#{name}=/) }.each do |name|
        board.fail('env-example', "no #{name}")
      end
    end
  end
end
