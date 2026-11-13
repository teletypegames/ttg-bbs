# frozen_string_literal: true

require 'fileutils'
require 'json'

# A machine's photo for both faces: the file Wikidata names for it (P18) on Wikimedia Commons, shown
# only under a free licence (FREE: public domain, CC0, CC BY, CC BY-SA), always with its author
# and licence. The pictures made are kept on disk in +dir+ (one JSON a machine, a refused licence
# too), so Commons is asked once a machine.
class PictureService
  # The licences a photo may have to be shown, by Commons' short name.
  FREE = /\A(public domain|pd\b|cc0|cc[- ]by(-sa)?[- ]\d)/i
  # The pixels of each face: the modern one draws two a cell (half blocks), the C64 one too.
  MODERN = [72, 44].freeze
  C64    = [38, 40].freeze

  def initialize(commons:, pixels:, dir:)
    @commons = commons
    @pixels  = pixels
    @dir     = dir
    @lock    = Mutex.new
  end

  # The PictureModel of +machine+, or why not: :no_image (Wikidata names no photo, or Commons has
  # no such file), :not_free (its licence is not one of FREE), :unavailable (Commons or
  # ImageMagick failed).
  def picture(machine)
    return :no_image unless machine.image

    cached(machine) || make(machine)
  rescue Rubbs::Common::Web::HTTP::Error, PixelRepository::Error => e
    Rubbs.log('pictures', "#{machine.id} #{machine.image}: #{e.class}: #{e.message}")
    :unavailable
  end

  private

  def make(machine)
    info = @commons.info(machine.image)
    return store(machine, 'no_image' => true) && :no_image unless info&.thumb
    return store(machine, 'not_free' => info.license) && :not_free unless info.license.match?(FREE)

    picture = draw(machine, info, @commons.thumbnail(info.thumb))
    store(machine, picture.to_h.transform_keys(&:to_s))
    picture
  end

  def draw(machine, info, bytes)
    PictureModel.new(
      file:        machine.image,
      artist:      info.artist,
      license:     info.license,
      license_url: info.license_url,
      page:        info.page,
      modern:      @pixels.pixels(bytes, width: MODERN[0], height: MODERN[1]),
      c64:         @pixels.pixels(bytes, width: C64[0], height: C64[1], c64: true)
    )
  end

  def cached(machine)
    data = @lock.synchronize { File.exist?(path(machine)) && JSON.parse(File.read(path(machine))) }
    return nil unless data.is_a?(Hash) && data['image'] == machine.image
    return :no_image if data['no_image']
    return :not_free if data['not_free']

    PictureModel.from_h(data)
  rescue JSON::ParserError
    nil
  end

  # Writes +data+ as the machine's file; returns +data+.
  def store(machine, data)
    @lock.synchronize do
      FileUtils.mkdir_p(@dir)
      tmp = "#{path(machine)}.tmp"
      File.write(tmp, JSON.generate(data.merge('image' => machine.image)))
      File.rename(tmp, path(machine))
    end
    data
  end

  def path(machine) = File.join(@dir, "#{machine.id}.json")
end
