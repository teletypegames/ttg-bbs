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
    exhibition = ExhibitionService.new(WorkRepository.new(File.join(@dir, 'works')), canvas: canvas, cooldown: 0, per_hour: 10)
    @board = Board.new({ gallery: nil, canvas: canvas, exhibition: exhibition })
  end

  def test_the_c64_menu_logs_off
    session = Rubbs::Test::Session.new(petscii: true, keys: ['q'])
    UI::Petscii.new(session, {}, @board).run

    assert_includes session.output, 'the petscii & ansi art gallery'
    assert_includes session.output.gsub(/\e\[[\d;]*m/, ''), 'the exhibition 0 works'
  end

  def test_the_c64_exhibition_is_empty_at_first
    session = Rubbs::Test::Session.new(petscii: true, keys: ['3', ' ', 'q'])
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
end
