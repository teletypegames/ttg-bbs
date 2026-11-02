# frozen_string_literal: true

require 'yaml'

# The categories of config/categories.yml, in the order a caller sees them.
# They are not in the database: a change is a commit to the file.
class CategoryRepository
  def initialize(path)
    @path = path
  end

  # The CategoryModels of the file. Raises SystemCallError, Psych::Exception
  # or KeyError when the file is missing or wrong.
  def all = Array(YAML.safe_load_file(@path)).map { |entry| CategoryModel.from_entry(entry) }.freeze
end
