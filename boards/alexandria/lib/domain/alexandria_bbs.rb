# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the article service
# wired to the Wikipedias of ALEXANDRIA_BBS_LANGUAGES.
class AlexandriaBBS
  include BBS::Domain

  setting :languages, %w[en hu]

  service(:articles) { ArticleService.new(WikipediaRepository.new(languages: languages), languages: languages) }
end
