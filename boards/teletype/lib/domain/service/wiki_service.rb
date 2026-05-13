# frozen_string_literal: true

class WikiService
  def initialize(repo) = @repo = repo

  def list(category)         = @repo.list(category)
  def content(page_id)       = @repo.content(page_id)
  def page_url(locale, path) = @repo.page_url(locale, path)
end
