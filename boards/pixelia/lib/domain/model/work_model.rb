# frozen_string_literal: true

require 'time'

# A picture on the Exhibition: its id (which sorts by time), title, the handle
# of who hung it, when, and the picture itself, of one of two kinds: a
# +:canvas+ work saved from the shared canvas (CanvasModel), or a +:petscii+
# work uploaded from TTG Canvas 64 (PetsciiModel). The picture is kept as its
# JSON and made a model when asked for, so a long Exhibition stays small in
# memory.
class WorkModel
  KINDS = %i[canvas petscii].freeze

  attr_reader :id, :title, :handle, :created_at, :kind

  def initialize(id:, title:, handle:, created_at:, canvas: nil, petscii: nil)
    @id         = id
    @title      = title
    @handle     = handle
    @created_at = created_at
    @kind       = petscii ? :petscii : :canvas
    @picture    = (petscii || canvas).to_h.freeze
    freeze
  end

  def petscii? = @kind == :petscii

  # The CanvasModel of a canvas work; nil for a PETSCII work.
  def canvas = petscii? ? nil : CanvasModel.from_h(@picture)

  # The PetsciiModel of a PETSCII work; nil for a canvas work.
  def petscii = petscii? ? PetsciiModel.from_h(@picture) : nil

  def date = @created_at.strftime('%Y-%m-%d')

  def to_h
    {
      'id'         => @id,
      'title'      => @title,
      'handle'     => @handle,
      'created_at' => @created_at.iso8601,
      @kind.to_s   => @picture
    }
  end

  # A work from its JSON Hash; nil when it is not one.
  def self.from_h(hash)
    return nil unless hash.is_a?(Hash) && hash['id'].is_a?(String)

    picture = picture_of(hash) or return nil
    new(
      id:         hash['id'],
      title:      hash['title'].to_s,
      handle:     hash['handle'].to_s,
      created_at: Time.iso8601(hash['created_at'].to_s),
      **picture
    )
  rescue ArgumentError
    nil
  end

  # The picture of a work's JSON as the keyword of ::new; nil when it has none.
  def self.picture_of(hash)
    if hash.key?('petscii')
      petscii = PetsciiModel.from_h(hash['petscii'])
      petscii && { petscii: petscii }
    else
      canvas = CanvasModel.from_h(hash['canvas'])
      canvas && { canvas: canvas }
    end
  end
  private_class_method :picture_of
end
