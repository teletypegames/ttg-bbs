# frozen_string_literal: true

# One board TTG Gate BBS dials: a record of config/boards.yml.
class BoardModel
  attr_reader :id, :name, :summary, :tags, :host, :port, :public_host, :accent

  # [record]      one entry of the boards list, String keys
  # [host]        where the gate dials it
  # [public_host] the address shown to the caller
  def initialize(record, host:, public_host:)
    @id          = record.fetch('id').to_s
    @name        = record.fetch('name').to_s
    @summary     = record['summary'].to_s
    @tags        = Array(record['tags']).map(&:to_s).freeze
    @port        = Integer(record.fetch('port'))
    @accent      = record['accent'].to_s.match?(/\A#\h{6}\z/) ? record['accent'] : '#c0c0c0'
    @petscii     = record['petscii'] == true
    @enabled     = record['enabled'] != false
    @host        = host
    @public_host = public_host
    freeze
  end

  def petscii? = @petscii

  def enabled? = @enabled

  def address = "#{public_host} #{port}"

  # The accent as [red, green, blue], 0-255 each.
  def rgb = accent.delete('#').scan(/../).map { |h| h.to_i(16) }
end
