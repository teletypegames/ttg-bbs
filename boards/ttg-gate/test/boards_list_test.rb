# frozen_string_literal: true

require_relative 'test_helper'

# The gate's list of our boards and the boards themselves: a signed-in
# caller's key is for the id, so the id must be the name the board knows
# itself by (its folder and -bbs, the slug of its Rubbs.board).
class BoardsListTest < Minitest::Test
  BOARDS = File.expand_path('../..', __dir__)

  def ids = YAML.safe_load_file(File.expand_path('../config/boards.yml', __dir__)).fetch('boards').map { |b| b['id'] }

  def records = YAML.safe_load_file(File.expand_path('../config/boards.yml', __dir__)).fetch('boards')

  # Every board but the gate; the private ones (boards.yml: private) with a
  # role and not published.
  def test_every_id_is_a_boards_own_name
    folders = Dir.glob('*/bbs.rb', base: BOARDS).map { |path| File.dirname(path) } - ['ttg-gate']
    assert_equal folders.map { |f| "#{f}-bbs" }.sort, ids.sort
    folders.select { |f| TTG::Badges.private?(f) }.each do |f|
      record = records.find { |r| r['id'] == "#{f}-bbs" }
      assert record['role'], "#{f} is private: only a role shows it"
      assert record['local'], "#{f} is private: its port is not published"
    end
  end

  def directory
    path = File.expand_path('../config/boards.yml', __dir__)
    DirectoryService.new(BoardRepository.new(path, host: 'gw', public_host: 'example.org'))
  end

  def identity(*roles) = Rubbs::Common::Auth::Identity.new(id: 1, name: 'Tasi', roles: roles, source: :login)

  def test_monitor_only_for_the_grafana_role
    refute_includes directory.boards.map(&:id), 'monitor-bbs'
    refute_includes directory.boards(identity: Rubbs::Common::Auth::Identity.guest).map(&:id), 'monitor-bbs'
    refute_includes directory.boards(identity: identity('member')).map(&:id), 'monitor-bbs'
    monitor = directory.boards(petscii: true, identity: identity('member', 'grafana')).find { |b| b.id == 'monitor-bbs' }
    assert_equal ['127.0.0.1', 2336, 'through the gate'], [monitor.host, monitor.port, monitor.address]
    assert_equal directory.boards.size + 1, directory.boards(identity: identity('grafana')).size
  end

  def test_the_key_goes_to_the_id
    board = Struct.new(:host, :port, :name, :id).new('localhost', 1, 'TTG Wiki BBS', 'wiki-bbs')
    options = nil
    line = Class.new { def call(_session) = nil }.new
    Rubbs::Common::Line::Gateway.stub(:new, lambda { |**given|
      options = given
      line
    }) { UI.dial(Object.new, board) }
    assert_equal 'wiki-bbs', options[:audience]
  end
end
