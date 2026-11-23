# frozen_string_literal: true

require 'test_helper'
require 'rubbs/test'
require_relative '../../lib/ui/modern'
require_relative '../../lib/ui/petscii'

# Both faces on a fake line, over a canvas and a Exhibition in a temporary folder.
class FacesTest < Minitest::Test
  include TmpDir

  Board = Struct.new(:services)

  def setup
    super
    canvas = CanvasService.new(CanvasRepository.new(
                                 File.join(@dir, 'canvas.json'),
                                 archive_dir: File.join(@dir, 'a'),
                                 clear_flag:  File.join(@dir, 'c')
                               ))
    @notes = []
    exhibition = ExhibitionService.new(
      WorkRepository.new(File.join(@dir, 'works')),
      canvas:   canvas,
      cooldown: 0,
      per_hour: 10,
      notify:   ->(work, actor) { @notes << [work.title, actor&.name] }
    )
    @board = Board.new({ gallery: nil, canvas: canvas, exhibition: exhibition })
  end

  def test_the_c64_menu_logs_off
    session = Rubbs::Test::Session.new(petscii: true, keys: ['q'])
    UI::Petscii.new(session, {}, @board).run

    assert_includes session.output, 'the petscii & ansi art gallery'
    assert_includes session.output.gsub(/\e\[[\d;]*m/, ''), 'the exhibition 0 works'
  end

  def test_the_c64_exhibition_is_empty_at_first
    session = Rubbs::Test::Session.new(petscii: true, keys: ['3', '1', ' ', 'q', 'q'])
    UI::Petscii.new(session, {}, @board).run

    assert_includes session.output, 'nothing on the exhibition yet'
  end

  def test_the_desktop_says_who_paints
    before = Rubbs.config.board
    Rubbs.config.board = @board
    session = Rubbs::Test::Session.new(keys: [:alt_x])
    UI::Modern::APP.run(session: session, session_id: 'test')

    assert_includes session.output, 'The PETSCII & ANSI art gallery'
    assert_includes session.output, '0 painting'
  ensure
    Rubbs.config.board = before
  end

  # What the caller read, without escapes and line breaks.
  def read(session) = session.output.gsub(/\e\[[\d;]*[A-Za-z]/, '').gsub(/\s+/, ' ')

  def ada = Rubbs::Common::Auth::Identity.new(id: 7, name: 'ada', source: :login)

  def c64_upload(keys, received, identity: ada)
    session = Rubbs::Test::Session.new(petscii: true, keys: ['3', 'u', *keys, 'q', 'q'], identity: identity)
    Rubbs::Common::Files::Transfer.stub(:receive, received) { UI::Petscii.new(session, {}, @board).run }
    session
  end

  def test_a_c64_uploads_a_picture_by_xmodem_and_it_hangs_at_once
    session = c64_upload([*'Logo'.chars, :enter, ' '], tcv_fixture('ttg-logo'))
    out = read(session)
    assert_includes out, 'XMODEM upload of your .tcv picture'
    assert_includes out, 'The picture came in: upper case set'
    assert_includes out, 'On the Exhibition: "Logo" by ada.'
    assert_equal [%w[Logo ada]], @notes
    assert @board.services[:exhibition].all.first.petscii?
  end

  def test_a_guest_is_sent_to_log_in_first
    session = c64_upload([' '], tcv_fixture('ttg-logo'), identity: nil)
    assert_includes read(session), 'log in or make an account first'
    assert_empty @board.services[:exhibition].all
  end

  def test_game_graphics_and_broken_files_are_refused_in_words
    session = c64_upload([' '], tcv_fixture('game-tiles'))
    assert_includes read(session), 'That is game graphics'
    session = c64_upload([' '], 'not a picture at all'.b)
    assert_includes read(session), 'not a picture the Exhibition can read: not a TTG Canvas 64 picture.'
    session = c64_upload([' '], :timeout)
    assert_includes read(session), 'did not send the file by XMODEM in time'
    assert_empty @board.services[:exhibition].all
    assert_empty @notes
  end

  def test_a_c64_sees_a_petscii_work_in_its_own_character_set
    picture = PetsciiModel.from_tcv(TcvModel.parse(tcv_fixture('ttg-logo')))
    @board.services[:exhibition].hang('k', title: 'Logo', handle: 'ada', picture: picture)
    session = Rubbs::Test::Session.new(petscii: true, keys: ['3', '1', '1', :enter, ' ', 'q', 'q', 'q'])
    UI::Petscii.new(session, {}, @board).run
    raw = session.raw
    screen = UI::Petscii::WorkScreen.bytes(picture)
    assert_includes raw, screen
    assert_equal Rubbs::Petscii::Canvas::UPPERCASE, screen.getbyte(0)
    assert_includes raw[(raw.index(screen) + screen.bytesize)..], [Rubbs::Petscii::Canvas::LOWERCASE].pack('C')
  end
end
