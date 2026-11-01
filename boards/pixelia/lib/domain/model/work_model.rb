# frozen_string_literal: true

require 'time'

# A picture saved from the canvas to the Wall: its id (which sorts by time),
# title, the handle of who saved it, when, and the picture itself. The
# picture is kept as its JSON rows (75 strings) and made a CanvasModel when
# asked for, so a long Wall stays small in memory.
class WorkModel
  attr_reader :id, :title, :handle, :created_at

  def initialize(id:, title:, handle:, created_at:, canvas:)
    @id         = id
    @title      = title
    @handle     = handle
    @created_at = created_at
    @rows       = canvas.to_h.freeze
    freeze
  end

  def canvas = CanvasModel.from_h(@rows)

  def date = @created_at.strftime('%Y-%m-%d')

  def to_h
    { 'id' => @id, 'title' => @title, 'handle' => @handle, 'created_at' => @created_at.iso8601,
      'canvas' => @rows }
  end

  # A work from its JSON Hash; nil when it is not one.
  def self.from_h(hash)
    return nil unless hash.is_a?(Hash)

    canvas = CanvasModel.from_h(hash['canvas'])
    return nil unless canvas && hash['id'].is_a?(String)

    new(id: hash['id'], title: hash['title'].to_s, handle: hash['handle'].to_s,
        created_at: Time.iso8601(hash['created_at'].to_s), canvas: canvas)
  rescue ArgumentError
    nil
  end
end
