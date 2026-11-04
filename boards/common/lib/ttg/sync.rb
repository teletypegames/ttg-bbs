# frozen_string_literal: true

require 'erb'
require 'yaml'
require 'bbs/check'

module TTG
  # The files every TTG board shares, written from the templates in
  # lib/ttg/board by <tt>rake ttg:sync</tt>: the Dockerfile (keeping the
  # board's own packages on its +apk add+ line), .dockerignore and
  # .woodpecker.yaml (with the board's name and port). <tt>rake bbs:check</tt>
  # (TTG::Check) fails while a board's copy differs.
  module Sync
    # The folder of the templates.
    BOARD = File.join(__dir__, 'board')
    # The canonical Dockerfile; a board may add packages to its +apk add+ line.
    DOCKERFILE = File.read(File.join(BOARD, 'Dockerfile')).freeze
    # The canonical .dockerignore.
    DOCKERIGNORE = File.read(File.join(BOARD, 'dockerignore')).freeze
    # The template of .woodpecker.yaml, given +slug+ and +port+.
    WOODPECKER = ERB.new(File.read(File.join(BOARD, 'woodpecker.yaml.erb')), trim_mode: '-')
    # The +apk add+ line of the canonical Dockerfile.
    APK = DOCKERFILE[/^RUN apk add .*$/]

    # The files of the board at +root+ as they should be: path => content.
    def self.files(root)
      board = BBS::Check::Board.new(root)
      {
        'Dockerfile' => dockerfile(board.read('Dockerfile')),
        '.dockerignore' => DOCKERIGNORE,
        '.woodpecker.yaml' => woodpecker(board.slug, port(board))
      }
    end

    # Writes the files of #files that differ. Returns the paths written.
    def self.run(root)
      files(root).filter_map do |path, content|
        target = File.join(root, path)
        next if File.file?(target) && File.read(target) == content

        File.write(target, content)
        path
      end
    end

    # The canonical Dockerfile with the packages +current+ (a board's
    # Dockerfile, or +nil+) adds to its +apk add+ line.
    def self.dockerfile(current)
      extra = current.to_s[/^RUN apk add .*$/].to_s.delete_prefix(APK).strip
      extra.empty? ? DOCKERFILE : DOCKERFILE.sub(APK, "#{APK} #{extra}")
    end

    # The pipeline of the board +slug+ on the public +port+.
    def self.woodpecker(slug, port) = WOODPECKER.result_with_hash(slug: slug, port: port)

    # The public telnet port of +board+ (a BBS::Check::Board) in its
    # compose.yaml, or +nil+.
    def self.port(board)
      services = YAML.safe_load(board.read('compose.yaml').to_s)&.fetch('services', {}) || {}
      Array(services.dig(board.slug, 'ports')).first.to_s.split(':').first&.to_i
    end
  end
end
