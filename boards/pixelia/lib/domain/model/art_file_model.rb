# frozen_string_literal: true

# A file of a 16colo.rs pack, from the pack's listing in the API: its name,
# its pack, the artists the archive credits and the SAUCE record the archive
# read from it (title, author, group, data and file type, width, iCE colours).
class ArtFileModel
  TEXT_EXTENSIONS = %w[.ans .asc .diz .nfo .txt .ice].freeze
  # SAUCE data type 1 is character art; its file types 0-2 are ASCII, ANSI
  # and ANSiMation, the ones that are text with escape sequences.
  SAUCE_CHARACTER = 1
  SAUCE_TEXT_TYPES = (0..2)

  attr_reader :name, :pack, :artists, :title, :author, :group, :datatype, :filetype, :width, :date

  def initialize(
    name:,
    pack:,
    artists: [],
    title: '',
    author: '',
    group: '',
    datatype: nil,
    filetype: nil,
    width: nil,
    ice: false,
    date: ''
  )
    @name     = name
    @pack     = pack
    @artists  = artists
    @title    = title
    @author   = author
    @group    = group
    @datatype = datatype
    @filetype = filetype
    @width    = width
    @ice      = ice
    @date     = date
    freeze
  end

  def ice? = @ice

  def extension = File.extname(@name).downcase

  # A text-art file: one of the text extensions, or a file whose SAUCE says
  # it is character art (packs give their ANSIs the group's own extension,
  # .RAT, .ACI, .CIA …). Images, executables and binary text are not.
  def text_art?
    return @datatype == SAUCE_CHARACTER && SAUCE_TEXT_TYPES.cover?(@filetype) if @datatype

    TEXT_EXTENSIONS.include?(extension)
  end

  # Who made it: the SAUCE author and group, else the archive's artists.
  def credits
    names = [@author, @group].reject(&:empty?)
    names = @artists if names.empty?
    names.join(' / ')
  end

  # One file of a pack's listing in the API; nil when it is not one. The
  # names and the SAUCE texts come from afar, so they are cleaned.
  def self.from_api(name, hash, pack)
    return nil unless name.is_a?(String) && hash.is_a?(Hash)

    sauce = hash['sauce'].is_a?(Hash) ? hash['sauce'] : {}
    new(
      name:    clean(name),
      pack:    pack,
      artists: Array(hash['artists']).map { |a| clean(a) },
      title:   clean(sauce['Title']),
      author:  clean(sauce['Author']),
      group:   clean(sauce['Group']),
      **sauce_facts(sauce)
    )
  end

  # The numbers of a SAUCE record in the API: types, width, iCE, date.
  def self.sauce_facts(sauce)
    flags = sauce['ansiflags'].is_a?(Hash) ? sauce['ansiflags'] : {}
    {
      datatype: sauce['Datatype']&.to_i,
      filetype: sauce['Filetype']&.to_i,
      width:    sauce['Tinfo1'].to_i.positive? ? sauce['Tinfo1'].to_i : nil,
      ice:      flags['ice'].to_i == 1,
      date:     date(sauce['Date'])
    }
  end

  def self.clean(text) = Rubbs::Common::Text.clean(text, keep_newlines: false).strip

  def self.date(value)
    s = value.to_s
    s.match?(/\A\d{8}\z/) ? "#{s[0, 4]}-#{s[4, 2]}-#{s[6, 2]}" : ''
  end
end
