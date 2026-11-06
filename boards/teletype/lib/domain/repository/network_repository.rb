# frozen_string_literal: true

require 'yaml'

# The town map's YAML (lib/content/network.yml): the clubhouse and the
# boards of the network, read once.
class NetworkRepository
  def initialize(path) = @path = path

  def clubhouse = board(data.fetch('clubhouse'))

  def boards = data.fetch('boards').map { |b| board(b) }

  private

  def data = @data ||= YAML.safe_load_file(@path)

  def board(row)
    place = (row['place'] || {}).to_h { |face, at| [face.to_sym, at] }
    NetworkBoardModel.new(**row.except('place').transform_keys(&:to_sym), place: place)
  end
end
