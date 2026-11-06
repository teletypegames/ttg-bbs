# frozen_string_literal: true

require 'yaml'
require 'rubbs/common/board/check'

module TTG
  # The house rules of the Teletype Games boards, added to Rubbs::Common::Board::Check: the
  # names, the files every board has, its place in the boards.yml of the
  # repository (port, caller limit, memory), the shared RuboCop rules, the
  # preset, and every setting of the domain in env-example.
  module Check
    # The files every board has besides those rubbs asks for.
    FILES = %w[.rubocop.yml env-example].freeze
    # The public ports of the boards.
    PORTS = 2300..2399
    # What every board says in boards.yml.
    SETTINGS = %w[port max_sessions memory].freeze
    # The shared RuboCop rules, as a board's .rubocop.yml inherits them.
    RUBOCOP = %r{^inherit_gem:\s*\n\s+ttg-common:\s+lib/ttg/board/rubocop\.yml\s*$}

    # The boards.yml of the repository a board's folder +root+ is in
    # (<tt>boards/<name></tt>, the file two folders up), or +nil+.
    def self.settings_file(root)
      file = File.expand_path('../../boards.yml', root)
      File.file?(file) ? file : nil
    end

    Rubbs::Common::Board::Check.rule(
      :ttg_name,
      'the technical name is <slug>-bbs, the folder the slug without -bbs'
    ) do |board|
      slug = board.slug
      next board.fail('bbs.rb', 'no Rubbs.board title') unless slug

      board.fail('bbs.rb', "the technical name #{slug} does not end with -bbs") unless slug.end_with?('-bbs')
      folder = File.basename(board.root)
      board.fail('.', "the folder #{folder} is not #{slug.delete_suffix('-bbs')}") unless "#{folder}-bbs" == slug
    end

    Rubbs::Common::Board::Check.rule(:ttg_files, 'the files of a TTG board') do |board|
      FILES.each { |path| board.fail(path, 'missing') unless board.file?(path) }
    end

    Rubbs::Common::Board::Check.rule(:ttg_settings, 'the board is in boards.yml with its port, callers and memory') do |board|
      name = File.basename(board.root)
      file = Check.settings_file(board.root)
      next board.fail('../../boards.yml', 'missing: the board is not in a repository of boards') unless file

      entry = (YAML.safe_load_file(file) || {})[name]
      next board.fail('../../boards.yml', "no #{name}") unless entry.is_a?(Hash)

      SETTINGS.each { |key| board.fail('../../boards.yml', "#{name}: no #{key}") unless entry.key?(key) }
      board.fail('../../boards.yml', "#{name}: port not in #{PORTS}") unless PORTS.cover?(entry['port'].to_i)
    end

    Rubbs::Common::Board::Check.rule(:ttg_preset, 'bbs.rb uses the TTG preset') do |board|
      text = board.read('bbs.rb').to_s
      board.fail('bbs.rb', "no require 'ttg/common'") unless text.include?("require 'ttg/common'")
      board.fail('bbs.rb', 'no preset TTG::PRESET') unless text.match?(/^\s*preset\s+TTG::PRESET\b/)
    end

    Rubbs::Common::Board::Check.rule(:ttg_rubocop, '.rubocop.yml inherits the shared rules of ttg-common') do |board|
      text = board.read('.rubocop.yml')
      board.fail('.rubocop.yml', 'no inherit_gem: ttg-common: lib/ttg/board/rubocop.yml') if text && !text.match?(RUBOCOP)
    end

    Rubbs::Common::Board::Check.rule(
      :ttg_auth,
      'a board with accounts or a Central lists RUBBS_AUTH_SECRET in env-example'
    ) do |board|
      next unless board.read('bbs.rb').to_s.match?(/^\s*(auth|central)\b/)

      example = board.read('env-example').to_s
      unless example.match?(/^#?\s*RUBBS_AUTH_SECRET=/)
        board.fail('env-example', 'no RUBBS_AUTH_SECRET (the board has auth or central)')
      end
    end

    Rubbs::Common::Board::Check.rule(:ttg_env, 'env-example lists every setting of the domain') do |board|
      example = board.read('env-example')
      domain  = board.declaration[:domain]
      next unless example && domain && board.file?('lib/domain.rb')

      Rubbs.config.env_prefix = board.env_prefix
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
