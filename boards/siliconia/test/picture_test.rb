# frozen_string_literal: true

require 'test_helper'
require_relative '../lib/ui/picture'

class PictureTest < Minitest::Test
  include TmpData

  # Commons from memory: the C64's file is public domain, the Game Boy's not free.
  class Commons
    attr_reader :asked

    def initialize = @asked = 0

    def info(name)
      @asked += 1
      license = name.start_with?('C64') ? 'Public domain' : 'All rights reserved'
      CommonsRepository::Info.new(
        thumb:       "https://x/#{name}",
        license:     license,
        license_url: '',
        artist:      'Evan-Amos',
        page:        "https://commons.wikimedia.org/wiki/File:#{name}"
      )
    end

    def thumbnail(_url) = 'jpeg'
  end

  # Pixels from memory: a red pixel over a black one.
  class Pixels
    def pixels(*, **) = PixelsModel.new(width: 1, height: 2, rgb: [200, 0, 0, 0, 0, 0])
  end

  def machine(id, image) = MachineModel.from_record({ 'id' => id, 't' => id, 'img' => image })

  def service(commons = Commons.new) = PictureService.new(commons: commons, pixels: Pixels.new, dir: path('pictures'))

  def test_a_free_photo_is_made_once_and_kept
    commons = Commons.new
    first   = service(commons).picture(machine('Q1', 'C64.jpg'))
    again   = service(commons).picture(machine('Q1', 'C64.jpg'))
    assert_equal ['Evan-Amos, Public domain', [200, 0, 0]], [again.credit, again.modern.at(0, 0)]
    assert_equal first, again
    assert_equal 1, commons.asked
  end

  def test_no_photo_and_a_photo_not_free
    assert_equal :no_image, service.picture(machine('Q2', nil))
    commons = Commons.new
    assert_equal :not_free, service(commons).picture(machine('Q3', 'GB.jpg'))
    assert_equal :not_free, service(commons).picture(machine('Q3', 'GB.jpg'))
    assert_equal 1, commons.asked
  end

  def test_a_failure_is_unavailable
    broken = Commons.new
    broken.define_singleton_method(:info) { |_| raise Rubbs::Common::Web::HTTP::Error, 'timeout' }
    assert_equal :unavailable, service(broken).picture(machine('Q1', 'C64.jpg'))
  end

  def test_the_faces_draw_half_blocks
    pixels = PixelsModel.new(width: 2, height: 2, rgb: [255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    assert_equal ["\e[38;5;231;48;5;16m▀\e[38;5;16;48;5;16m▀\e[0m"], UI::Picture.modern_lines(pixels)
    assert_equal [[[0xa2, Rubbs::Petscii::Canvas::WHITE, true], [0x20, Rubbs::Petscii::Canvas::BLACK, false]]],
                 UI::Picture.c64_cells(pixels)
  end

  def test_magick_output_is_read_as_ppm
    repo = PixelRepository.new(command: ['sh', '-c', "printf 'P6\\n2 1\\n255\\n\\001\\002\\003\\004\\005\\006'", '--'])
    assert_equal [2, 1, [1, 2, 3, 4, 5, 6]], repo.pixels('x', width: 2, height: 1).deconstruct
  end
end
