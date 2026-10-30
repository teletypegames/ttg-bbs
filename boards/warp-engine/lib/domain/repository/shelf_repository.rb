# frozen_string_literal: true

require 'yaml'

# The shelves of config/shelves.yml, in the order of the menus.
class ShelfRepository
  attr_reader :all

  def initialize(path)
    @all = Array(YAML.safe_load_file(path)).map { |entry| ShelfModel.from_entry(entry) }.freeze
  rescue SystemCallError, Psych::Exception, KeyError => e
    warn "warp-engine-bbs: no shelves from #{path}: #{e.class}: #{e.message}"
    @all = [].freeze
  end
end
