# frozen_string_literal: true

require_relative '../test_helper'
require 'ttg/common'

# The posts, oneliners and letters to the sysop of before, handed over once
# to the network's wall and feedback on a Central of the test's own.
class ExportServiceTest < Minitest::Test
  include DatabaseCase

  NOW = Time.new(2026, 11, 6, 12)

  def setup
    super
    @dir = Dir.mktmpdir('teletype-export')
    Rubbs::Test.auth_secret
    @server = Rubbs::Common::Central::Server.new(services: [TTG::Wall::Service, TTG::Feedback::Service], data: @dir)
    Rubbs.config.central = Rubbs::Common::Central::Link.new(server: @server)
  end

  def teardown
    Rubbs.config.central = nil
    @server.stop
    Rubbs.config.auth_secrets = []
    FileUtils.rm_rf(@dir)
    super
  end

  def post(board, stamp, name, text)
    PostModel.create(board: board, timestamp: stamp, username: name, user_key: name.downcase, text: text)
  end

  def letter(id, to, stamp)
    LetterModel.create(
      id:            id,
      timestamp:     stamp,
      sender:        'Ada',
      recipient:     to,
      recipient_key: to.downcase,
      subject:       "to #{to}",
      body:          'Lovely board',
      read:          0
    )
  end

  def the_past
    post('general', '12-30 10:00', 'Kali', 'Hello all')
    post('tech', '01-02 09:00', 'Zed', "A long\npost")
    OnelinerModel.create(timestamp: '2025-12-31T12:00:00+01:00', username: 'Ada', text: 'Happy new year')
    letter('a1', 'Sysop', '2026-10-01T10:00:00+02:00')
    letter('a2', 'Kali', '2026-10-02T10:00:00+02:00')
  end

  def export
    counts = nil
    capture_io { counts = ExportService.new(now: NOW).call }
    counts
  end

  def wall_notes = @server.services['/wall'].store.recent(board: 'bbs', limit: 100)[:notes]

  def test_the_years_of_the_stamps_count_back_from_now
    post('general', '12-30 10:00', 'Kali', 'a')
    post('general', '01-02 09:00', 'Zed', 'b')
    post('general', '11-07 08:00', 'Ada', 'c')
    assert_equal(
      ['2024-12-30 10:00', '2025-01-02 09:00', '2025-11-07 08:00'],
      PostModel.dated(NOW).map { |_, time| time.strftime('%Y-%m-%d %H:%M') }
    )
  end

  def test_everything_goes_once_in_the_order_it_was_written
    the_past
    assert_equal({ wall: 3, feedback: 1 }, export)
    assert_equal({ wall: 0, feedback: 0 }, export)
    assert_equal(
      [['Kali', '[General] Hello all'], ['Ada', 'Happy new year'], ['Zed', "[Tech] A long\npost"]],
      wall_notes.map { |note| note.values_at(:name, :text) }
    )
    letters = @server.services['/feedback'].store.list[:items]
    assert_equal([%w[feedback read Ada bbs]], letters.map { |item| item.values_at(:kind, :state, :name, :board) })
  end

  def test_letters_between_names_stay_here
    the_past
    export
    assert_nil LetterModel['a2'].exported_at
    refute_nil LetterModel['a1'].exported_at
  end

  def test_long_posts_go_in_requests_the_central_takes
    25.times { |i| post('general', format('11-%02d 10:00', 1 + (i / 5)), 'Kali', "#{i} #{'x' * 900}") }
    assert_equal({ wall: 25, feedback: 0 }, export)
    assert_equal 25, wall_notes.size
  end

  def test_nothing_is_marked_when_the_central_is_away
    the_past
    Rubbs.config.central = nil
    assert_raises(RuntimeError) { export }
    assert_equal 2, PostModel.where(exported_at: nil).count
    assert_equal 1, OnelinerModel.unexported.size
  end
end
