# frozen_string_literal: true

require 'yaml'

# The categories of config/categories.yml, in the order a caller sees them.
# They are not in the database: a change is a commit to the file.
class CategoryRepository
  attr_reader :all

  def initialize(path)
    @all = Array(YAML.safe_load_file(path)).map { |entry| CategoryModel.from_entry(entry) }.freeze
  rescue SystemCallError, Psych::Exception, KeyError => e
    warn "ttg-blog-bbs: no categories from #{path}: #{e.class}: #{e.message}"
    @all = [].freeze
  end
end
