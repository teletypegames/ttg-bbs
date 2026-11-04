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
  YAML

  CI = <<~YAML
    steps:
      - name: rubocop
      - name: test
        commands:
          - bundle exec rake
      - name: check
      - name: deploy
  YAML

  def files
    { 'bbs.rb' => "require 'ttg/common'\nBBS.board 'Shop BBS' do\n  preset TTG::PRESET\nend\n",
      'Dockerfile' => TTG::Check::DOCKERFILE, '.dockerignore' => TTG::Check::DOCKERIGNORE,
      'compose.yaml' => COMPOSE, '.woodpecker.yaml' => CI, '.rubocop.yml' => '', 'LICENSE' => '', 'env-example' => '' }
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
    extra = TTG::Check::DOCKERFILE.sub(TTG::Check::APK, "#{TTG::Check::APK} rsync")
    with_board('Dockerfile' => extra) { |dir| assert_empty ttg_findings(dir) }
    with_board('Dockerfile' => "#{TTG::Check::DOCKERFILE}RUN echo\n") do |dir|
      assert_equal [:ttg_docker], ttg_findings(dir).map(&:rule)
    end
  end

  def test_what_breaks_the_house_rules
    changes = { 'compose.yaml' => COMPOSE.sub('restart: unless-stopped', 'restart: always'),
                '.woodpecker.yaml' => CI.sub('bundle exec rake', 'bundle exec rake test'),
                'bbs.rb' => "BBS.board 'Shop BBS' do\nend\n", 'LICENSE' => nil }
    with_board(changes) do |dir|
      assert_equal %i[ttg_ci ttg_compose ttg_files ttg_preset], ttg_findings(dir).map(&:rule).uniq.sort
    end
  end
end
