# frozen_string_literal: true

# What Wikipedia says about a machine: the lead of its English or Hungarian article.
class AboutService
  def initialize(wikipedia)
    @wikipedia = wikipedia
  end

  # The SummaryModel of +machine+ in +language+ ('en' or 'hu'), or why not: :no_article (Wikidata
  # knows no article in that language, or Wikipedia has none), :unavailable (Wikipedia did not
  # answer).
  def summary(machine, language = 'en')
    title = language == 'hu' ? machine.article_hu : machine.article
    return :no_article unless title

    found = @wikipedia.summary(title, language)
    found == :missing ? :no_article : found
  rescue Rubbs::Common::Web::HTTP::Error => e
    Rubbs.log('wikipedia', "#{language}:#{title}: #{e.message}")
    :unavailable
  end
end
