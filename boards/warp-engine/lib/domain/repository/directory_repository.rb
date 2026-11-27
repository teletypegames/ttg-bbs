# frozen_string_literal: true

require 'yaml'

# The directories of config/directories.yml, in the order of the menus.
class DirectoryRepository
  attr_reader :all

  def initialize(path)
    @all = Array(YAML.safe_load_file(path)).map { |entry| DirectoryModel.from_entry(entry) }.freeze
  rescue SystemCallError, Psych::Exception, KeyError => e
    Rubbs.log('directories', "none from #{path}: #{e.class}: #{e.message}")
    @all = [].freeze
  end
end
