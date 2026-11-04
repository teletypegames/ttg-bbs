# frozen_string_literal: true

require 'test_helper'
require 'ttg/check'
require 'fileutils'
require 'tmpdir'

class TTGCheckTest < Minitest::Test
  COMPOSE = <<~YAML
    services:
      shop-bbs:
        mem_limit: 160m
        cpus: 1.0
        pids_limit: 256
        build: .
        container_name: shop-bbs
        ports:
          - "2390:2323"
        restart: unless-stopped
        stop_grace_period: 30s
  YAML

  RUBOCOP = "inherit_gem:\n  ttg-common: lib/ttg/board/rubocop.yml\n"

  def files
    {
      'bbs.rb'           => "require 'ttg/common'\nBBS.board 'Shop BBS' do\n  preset TTG::PRESET\nend\n",
      'Dockerfile'       => TTG::Sync::DOCKERFILE,
      '.dockerignore'    => TTG::Sync::DOCKERIGNORE,
      'compose.yaml'     => COMPOSE,
      '.woodpecker.yaml' => TTG::Sync.woodpecker('shop-bbs', 2390),
      '.rubocop.yml'     => RUBOCOP,
      'LICENSE'          => '',
      'env-example'      => ''
    }
  end

  def with_board(changes = {})
    Dir.mktmpdir do |tmp|
      dir = File.join(tmp, 'shop-bbs')
      files.merge(changes).compact.each do |path, text|
        FileUtils.mkdir_p(File.join(dir, File.dirname(path)))
        File.write(File.join(dir, path), text)
      end
      yield dir
    end
  end

  def ttg_findings(dir) = BBS::Check.run(dir).select { |f| f.rule.to_s.start_with?('ttg_') }

  def test_a_board_by_the_house_rules
    with_board { |dir| assert_empty ttg_findings(dir) }
  end

  def test_a_dockerfile_may_only_add_packages
    extra = TTG::Sync::DOCKERFILE.sub(TTG::Sync::APK, "#{TTG::Sync::APK} rsync")
    with_board('Dockerfile' => extra) { |dir| assert_empty ttg_findings(dir) }
    with_board('Dockerfile' => "#{TTG::Sync::DOCKERFILE}RUN echo\n") do |dir|
      assert_equal [:ttg_docker], ttg_findings(dir).map(&:rule)
    end
  end

  def test_what_breaks_the_house_rules
    changes = {
      'compose.yaml'     => COMPOSE.sub('restart: unless-stopped', 'restart: always'),
      '.woodpecker.yaml' => TTG::Sync.woodpecker('shop-bbs', 2390).sub('bundle exec rake', 'bundle exec rake test'),
      '.rubocop.yml'     => "AllCops:\n  NewCops: enable\n",
      'bbs.rb'           => "BBS.board 'Shop BBS' do\nend\n",
      'LICENSE'          => nil
    }
    with_board(changes) do |dir|
      assert_equal %i[ttg_ci ttg_compose ttg_files ttg_preset ttg_rubocop], ttg_findings(dir).map(&:rule).uniq.sort
    end
  end

  def test_another_service_of_the_image_has_no_health_check
    worker = "  shop-bbs-worker:\n    mem_limit: 64m\n    cpus: 0.5\n    pids_limit: 64\n    build: .\n    " \
             "container_name: shop-bbs-worker\n    restart: unless-stopped\n"
    with_board('compose.yaml' => COMPOSE + worker) do |dir|
      assert_equal(2, ttg_findings(dir).count { |f| f.message.start_with?('shop-bbs-worker:') })
    end
    quiet = "#{worker}    healthcheck:\n      disable: true\n    labels:\n      org.teletypegames.autoheal: \"false\"\n"
    with_board('compose.yaml' => COMPOSE + quiet) { |dir| assert_empty ttg_findings(dir) }
  end

  def test_the_board_service_gets_time_to_stop
    with_board('compose.yaml' => COMPOSE.sub("    stop_grace_period: 30s\n", '')) do |dir|
      assert_equal ['shop-bbs: no stop_grace_period'], ttg_findings(dir).map(&:message)
    end
  end

  def test_sync_writes_the_shared_files_and_keeps_the_packages
    extra = TTG::Sync::DOCKERFILE.sub(TTG::Sync::APK, "#{TTG::Sync::APK} rsync").sub('HEALTHCHECK', 'HEALTHCHECK --old')
    with_board('Dockerfile' => extra, '.woodpecker.yaml' => "steps: []\n", '.dockerignore' => nil) do |dir|
      assert_equal %w[Dockerfile .dockerignore .woodpecker.yaml], TTG::Sync.run(dir)
      assert_includes File.read(File.join(dir, 'Dockerfile')), "#{TTG::Sync::APK} rsync"
      pipeline = File.read(File.join(dir, '.woodpecker.yaml'))
      assert_includes pipeline, 'ci-deploy shop-bbs'
      assert_includes pipeline, 'public port 2390 only'
      assert_empty ttg_findings(dir)
      assert_empty TTG::Sync.run(dir)
    end
  end
end
