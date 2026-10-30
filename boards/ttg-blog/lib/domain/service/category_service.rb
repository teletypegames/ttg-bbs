# frozen_string_literal: true

# The categories a post can pick, and the name of the one it has.
class CategoryService
  def initialize(repo)
    @repo = repo
  end

  def all = @repo.all

  # The category of +id+; one that left the list shows its bare id.
  def find(id) = all.find { |c| c.id == id } || CategoryModel.unknown(id)

  def listed?(id) = all.any? { |c| c.id == id }
end
