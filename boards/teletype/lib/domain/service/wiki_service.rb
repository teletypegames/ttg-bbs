# frozen_string_literal: true

class WikiService
  def initialize(repo) = @repo = repo

  def list(category)         = @repo.list(category)
  def content(path)          = @repo.content(path)
  def page_url(locale, path) = @repo.page_url(locale, path)
end
