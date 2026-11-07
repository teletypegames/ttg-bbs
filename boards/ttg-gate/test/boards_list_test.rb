# frozen_string_literal: true

require_relative 'test_helper'

# The gate's list of our boards and the boards themselves: a signed-in
# caller's key is for the id, so the id must be the name the board knows
# itself by (its folder and -bbs, the slug of its Rubbs.board).
class BoardsListTest < Minitest::Test
  BOARDS = File.expand_path('../..', __dir__)

  def ids = YAML.safe_load_file(File.expand_path('../config/boards.yml', __dir__)).fetch('boards').map { |b| b['id'] }

  def test_every_id_is_a_boards_own_name
    folders = Dir.glob('*/bbs.rb', base: BOARDS).map { |path| File.dirname(path) } - ['ttg-gate']
    assert_equal folders.map { |f| "#{f}-bbs" }.sort, ids.sort
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
