# frozen_string_literal: true

require 'open3'

# Turns the bytes of a photo (JPEG, PNG, GIF) into a small PixelsModel with ImageMagick's
# +magick+: the plain background around the machine (a product photo's white) made black and cut
# off, then fitted into the size asked for, keeping its shape, flattened on black, as PPM. For the
# C64 (+c64+) the height is doubled first (its half-block pixels are twice as wide as high) and the
# colours made stronger, so its sixteen colours do not round them all to grey.
# Raises Error when ImageMagick is missing, takes longer than TIMEOUT seconds or cannot read it.
class PixelRepository
  # ImageMagick did not make a picture of the bytes.
  class Error < StandardError; end

  TIMEOUT = 15
  COMMAND = %w[magick].freeze

  # The C64's pixels: twice as high, the colours stronger.
  C64 = %w[-resize 100%x200% -modulate 105,170].freeze

  # The background flooded black from the corners (through a white frame, so a white backdrop
  # goes whole and a photo keeps its edges), then cut off.
  BACKGROUND = ['-bordercolor', 'white', '-border', '1', '-fuzz', '8%', '-fill', 'black', '-draw', 'color 0,0 floodfill',
                '-shave', '1x1', '-trim', '+repage'].freeze

  def initialize(command: COMMAND)
    @command = command
  end

  # The PixelsModel of +bytes+ fitted into +width+ × +height+ pixels.
  def pixels(bytes, width:, height:, c64: false)
    out, status = Open3.capture2(*command(width, height, c64), stdin_data: bytes, binmode: true)
    raise Error, "magick ended with #{status.exitstatus}" unless status.success?

    ppm(out)
  rescue SystemCallError => e
    raise Error, "magick: #{e.message}"
  end

  private

  def command(width, height, c64)
    ['timeout', TIMEOUT.to_s, *@command, '-limit', 'memory', '64MiB', '-', *BACKGROUND, *(c64 ? C64 : []),
     '-resize', "#{width}x#{height}", '-background', 'black', '-flatten', '-depth', '8', 'ppm:-']
  end

  # The pixels of a binary PPM (P6, 8 bits).
  def ppm(data)
    header = data.match(/\AP6\s+(\d+)\s+(\d+)\s+255\s/)
    raise Error, 'magick gave no PPM' unless header

    width  = header[1].to_i
    height = header[2].to_i
    rgb    = data.byteslice(header[0].bytesize, width * height * 3).to_s.unpack('C*')
    raise Error, 'the PPM is cut short' unless rgb.size == width * height * 3

    PixelsModel.new(width: width, height: height, rgb: rgb)
  end
end
