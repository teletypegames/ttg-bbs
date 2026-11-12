# frozen_string_literal: true

# One board TTG Gate BBS dials: a record of config/boards.yml.
class BoardModel
  attr_reader :id, :name, :summary, :tags, :host, :port, :public_host, :accent, :role

  # [record]      one entry of the boards list, String keys
  # [host]        where the gate dials it
  # [public_host] the address shown to the caller
  # [local_host]  where the gate dials a board that is not published
  #               (+local: true+): in its own container
  def initialize(record, host:, public_host:, local_host: '127.0.0.1')
    @id          = record.fetch('id').to_s
    @name        = record.fetch('name').to_s
    @summary     = record['summary'].to_s
    @tags        = Array(record['tags']).map(&:to_s).freeze
    @port        = Integer(record.fetch('port'))
    @accent      = BoardModel.accent(record['accent'])
    @petscii     = record['petscii'] == true
    @enabled     = record['enabled'] != false
    @role        = record['role']&.to_s
    @local       = record['local'] == true
    @host        = @local ? local_host : host
    @public_host = public_host
    freeze
  end

  # +value+ when it is a colour (#rrggbb), else light grey.
  def self.accent(value) = value.to_s.match?(/\A#\h{6}\z/) ? value : '#c0c0c0'

  def petscii? = @petscii

  def enabled? = @enabled

  # Whether the port is not published: only the gate reaches the board.
  def local? = @local

  # Whether the caller signed in as +identity+ sees the board: every caller
  # when it has no role, else only an account with the role.
  def for?(identity) = role.to_s.empty? || (identity.respond_to?(:role?) && identity.role?(role))

  def address = local? ? 'through the gate' : "#{public_host} #{port}"

  # The accent as [red, green, blue], 0-255 each.
  def rgb = accent.delete('#').scan(/../).map { |h| h.to_i(16) }
end
