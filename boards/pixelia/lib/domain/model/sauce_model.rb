# frozen_string_literal: true

# The SAUCE record at the end of an art file (the last 128 bytes, starting
# with "SAUCE00"): title, author, group and date, the data and file type,
# the width the art was drawn for and its iCE colours flag.
class SauceModel
  SIZE = 128
  ID   = 'SAUCE00'.b

  attr_reader :title, :author, :group, :date, :datatype, :filetype, :tinfo1, :tinfo2, :tflags

  def initialize(title:, author:, group:, date:, datatype:, filetype:, tinfo1:, tinfo2:, tflags:)
    @title    = title
    @author   = author
    @group    = group
    @date     = date
    @datatype = datatype
    @filetype = filetype
    @tinfo1   = tinfo1
    @tinfo2   = tinfo2
    @tflags   = tflags
    freeze
  end

  # Character art (data type 1) in ASCII, ANSI or ANSiMation (file type 0-2).
  def character? = @datatype == 1 && @filetype.between?(0, 2)

  # The width the art was drawn for, when the record gives one.
  def width = character? && @tinfo1.positive? ? @tinfo1 : nil

  # iCE colours: blink means a bright background.
  def ice? = @tflags.allbits?(1)

  # The record of +bytes+, an art file, its texts cleaned of control
  # characters; nil when it has none.
  def self.parse(bytes)
    bytes = bytes.to_s.b
    return nil if bytes.bytesize < SIZE

    record = bytes.byteslice(-SIZE, SIZE)
    return nil unless record.start_with?(ID)

    new(title: text(record, 7, 35), author: text(record, 42, 20), group: text(record, 62, 20),
        date: date(record.byteslice(82, 8)), datatype: record.getbyte(94), filetype: record.getbyte(95),
        tinfo1: record.byteslice(96, 2).unpack1('v'), tinfo2: record.byteslice(98, 2).unpack1('v'),
        tflags: record.getbyte(105))
  end

  def self.text(record, from, length)
    record.byteslice(from, length).force_encoding('IBM437')
          .encode('UTF-8', invalid: :replace, undef: :replace, replace: ' ')
          .then { |t| BBS::Text.clean(t, keep_newlines: false) }.strip
  end

  def self.date(raw)
    raw.match?(/\A\d{8}\z/) ? "#{raw[0, 4]}-#{raw[4, 2]}-#{raw[6, 2]}" : ''
  end
end
