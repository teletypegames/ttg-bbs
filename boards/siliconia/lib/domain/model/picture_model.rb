# frozen_string_literal: true

# A machine's photo from Wikimedia Commons, made small for both faces: +modern+ and +c64+ are
# PixelsModel, +file+ the Commons file name, +artist+, +license+ and +license_url+ its credit
# (shown under every picture), +page+ the file's page on Commons.
PictureModel = Data.define(:file, :artist, :license, :license_url, :page, :modern, :c64) do
  def self.from_h(data)
    new(
      **data.slice(*%w[file artist license license_url page]).transform_keys(&:to_sym),
      modern: PixelsModel.from_h(data['modern']),
      c64:    PixelsModel.from_h(data['c64'])
    )
  end

  def to_h = super.merge(modern: modern.to_h, c64: c64.to_h)

  # The credit line: who, under which licence.
  def credit = [artist, license].reject { |t| t.to_s.empty? }.join(', ')
end

# A small picture: +width+ × +height+ pixels, +rgb+ a flat Array of red, green, blue bytes, row by
# row.
PixelsModel = Data.define(:width, :height, :rgb) do
  def self.from_h(data) = new(width: data['width'].to_i, height: data['height'].to_i, rgb: Array(data['rgb']).map(&:to_i))

  # The [red, green, blue] of the pixel at +x+, +y+; black outside the picture.
  def at(x, y)
    return [0, 0, 0] unless x.between?(0, width - 1) && y.between?(0, height - 1)

    rgb[((y * width) + x) * 3, 3]
  end
end
