# frozen_string_literal: true

class WikiService
  def initialize(repo) = @repo = repo

  def list(tag, lang: 'en')        = @repo.list(tag, lang: lang)
  def section(prefix, lang: 'en')  = @repo.section(prefix, lang: lang)
  def content(path, lang: 'en')    = @repo.content(path, lang: lang)
  def page_url(path, lang: 'en')   = @repo.page_url(path, lang: lang)
end
