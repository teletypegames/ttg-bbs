# frozen_string_literal: true

require 'yaml'

# The board's own shelf of well-known books (config/classics.yml): their
# ebook numbers, with a title and an author so the shelf stands even before
# the catalog is imported.
class ClassicsRepository
  def initialize(path)
    @books = YAML.safe_load_file(path).map do |e|
      BookModel.stub(id: Integer(e.fetch('id')), title: e.fetch('title').to_s, author: e['author'].to_s,
                     language: e.fetch('language', 'en').to_s)
    end.freeze
  rescue SystemCallError, Psych::Exception, KeyError, ArgumentError, NoMethodError => e
    warn "scriptorium: #{path}: #{e.class}: #{e.message}"
    @books = [].freeze
  end

  def all = @books

  def find(id) = @books.find { |b| b.id == id }
end
