# frozen_string_literal: true

# A TTG Canvas 64 picture file (.tcv), read the safe way its FORMAT.md asks
# (tools/ttg-canvas-64): a load address in front is skipped, the header is
# checked, exactly 2016 or 4064 bytes are taken and what follows (XMODEM's
# padding) is ignored, every colour byte is masked to its low nibble. A newer
# version is refused, not guessed at. TcvModel.parse raises FormatError with
# a word on what is wrong.
class TcvModel
  MAGIC         = 'TC64'.b.freeze
  VERSION       = 1
  HEADER        = 16
  CELLS         = 1000
  CHARSET_BYTES = 2048
  ROM_LENGTH    = HEADER + (2 * CELLS)
  CUSTOM_LENGTH = ROM_LENGTH + CHARSET_BYTES
  LOAD_ADDRESS  = 2

  HIRES      = 0
  MULTICOLOR = 1
  ROM_UPPER  = 0
  ROM_LOWER  = 1
  CUSTOM     = 2

  # The file is not a picture this reader understands; the message says why.
  class FormatError < StandardError; end

  attr_reader :mode, :charset, :border, :background, :multicolor1, :multicolor2, :screen, :colors, :chars

  def initialize(header, screen, colors, chars)
    @mode, @charset, @border, @background, @multicolor1, @multicolor2 = header
    @screen = screen.freeze
    @colors = colors.freeze
    @chars  = chars
    freeze
  end

  def hires? = @mode == HIRES

  def custom_charset? = @charset == CUSTOM

  # The picture in the String +data+; raises FormatError.
  def self.parse(data)
    bytes = from_magic(data.to_s.b).bytes
    raise FormatError, 'the header is cut short' if bytes.size < HEADER

    check_header(bytes)
    custom = bytes[6] == CUSTOM
    length = custom ? CUSTOM_LENGTH : ROM_LENGTH
    raise FormatError, "the picture is cut short (#{bytes.size} of #{length} bytes)" if bytes.size < length

    colors = bytes[HEADER + CELLS, CELLS].map { |c| c & 0x0f }
    new(bytes[5, 6], bytes[HEADER, CELLS], colors, custom ? bytes[ROM_LENGTH, CHARSET_BYTES].pack('C*') : nil)
  end

  # +data+ from its magic on: two bytes of a load address in front are
  # skipped.
  def self.from_magic(data)
    data = data.byteslice(LOAD_ADDRESS..) if !data.start_with?(MAGIC) && data.byteslice(LOAD_ADDRESS, 4) == MAGIC
    raise FormatError, 'not a TTG Canvas 64 picture' unless data.start_with?(MAGIC)

    data
  end
  private_class_method :from_magic

  def self.check_header(bytes)
    version, mode, charset = bytes[4, 3]
    raise FormatError, "version #{version} is not known" unless version == VERSION
    raise FormatError, "mode #{mode} is not known" if mode > MULTICOLOR
    raise FormatError, "character set #{charset} is not known" if charset > CUSTOM
    raise FormatError, 'a colour is out of range' if bytes[7, 4].any? { |c| c > 15 }
  end
  private_class_method :check_header
end
