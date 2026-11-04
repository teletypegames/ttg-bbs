# frozen_string_literal: true

require 'yaml'
require 'bbs/check'

module TTG
  # The house rules of the Teletype Games boards, added to BBS::Check: the
  # names, the files every board has, the same Dockerfile and .dockerignore,
  # the limits of the compose service, the CI steps, the preset, and every
  # setting of the domain in env-example.
  module Check
    # The files of a TTG board beside rubbs' own.
    FILES = %w[Dockerfile compose.yaml .dockerignore .rubocop.yml .woodpecker.yaml LICENSE env-example].freeze
    # The folder of the canonical Dockerfile and .dockerignore.
    BOARD = File.join(__dir__, 'board')
    # The canonical Dockerfile; a board may add packages to its +apk add+ line.
    DOCKERFILE = File.read(File.join(BOARD, 'Dockerfile')).freeze
    # The canonical .dockerignore.
    DOCKERIGNORE = File.read(File.join(BOARD, 'dockerignore')).freeze
    # The +apk add+ line of the canonical Dockerfile.
    APK = DOCKERFILE[/^RUN apk add .*$/]
    # What a compose service sets for itself.
    COMPOSE_KEYS = %w[container_name mem_limit cpus pids_limit restart].freeze
    # The telnet ports of the boards.
    PORTS = 2300..2399
    # The steps of a board's pipeline.
    STEPS = %w[rubocop test check deploy].freeze

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

    BBS::Check.rule(:ttg_docker, 'the Dockerfile and .dockerignore of every TTG board') do |board|
      dockerfile = board.read('Dockerfile')
      if dockerfile
        apk  = dockerfile[/^RUN apk add .*$/].to_s
        same = dockerfile.sub(apk, APK) == DOCKERFILE && apk.start_with?(APK)
        board.fail('Dockerfile', 'differs from ttg-common lib/ttg/board/Dockerfile (only packages may be added)') unless same
      end
      ignore = board.read('.dockerignore')
      board.fail('.dockerignore', 'differs from ttg-common lib/ttg/board/dockerignore') if ignore && ignore != DOCKERIGNORE
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
      ports = Array(main['ports']).map { |p| p.to_s.split(':') }
      ok = ports.size == 1 && PORTS.cover?(ports[0][0].to_i) && ports[0][1] == '2323'
      board.fail('compose.yaml', "#{board.slug}: one port, 23xx:2323") unless ok
      services.except(board.slug).each do |name, service|
        board.fail('compose.yaml', "#{name}: only the board service has a port") if service['ports']
      end
    end

    BBS::Check.rule(:ttg_ci, 'the pipeline: rubocop, rake (tests and this check), compose check, deploy') do |board|
      text = board.read('.woodpecker.yaml')
      next unless text

      steps = Array(YAML.safe_load(text)['steps'])
      names = steps.map { |s| s['name'] }
      board.fail('.woodpecker.yaml', "steps are #{names.join(', ')}, not #{STEPS.join(', ')}") unless names == STEPS
      test = steps.find { |s| s['name'] == 'test' }
      runs = Array(test && test['commands'])
      board.fail('.woodpecker.yaml', 'the test step runs bundle exec rake') unless runs.include?('bundle exec rake')
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
