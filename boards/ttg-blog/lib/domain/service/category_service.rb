# frozen_string_literal: true

# The categories a post can pick, and the name of the one it has, read
# once at boot. A missing or broken list is logged and leaves no
# categories: the posts can still be read, but none can be written.
class CategoryService
  attr_reader :all

  def initialize(repo)
    @all = load(repo)
  end

  # The category of +id+; one that left the list shows its bare id.
  def find(id) = all.find { |c| c.id == id } || CategoryModel.unknown(id)

  def listed?(id) = all.any? { |c| c.id == id }

  private

  def load(repo)
    repo.all
  rescue SystemCallError, Psych::Exception, KeyError => e
    Rubbs.log('categories', e)
    [].freeze
  end
end
