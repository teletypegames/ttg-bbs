# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the article service
# wired to Wikipedia. The one place that reads the environment; both faces
# (lib/ui/modern, lib/ui/petscii) work on one instance of it.
class AlexandriaBBS
  attr_reader :articles

  def initialize
    languages = ENV.fetch('ALEXANDRIA_BBS_LANGUAGES', 'en,hu').split(',').map(&:strip).reject(&:empty?)
    @articles = ArticleService.new(WikipediaRepository.new(languages: languages), languages: languages)
  end

  # The services by name.
  def services = { articles: @articles }
end
