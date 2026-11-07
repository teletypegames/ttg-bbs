# frozen_string_literal: true

# What Wikipedia says about a game: the lead of its English article.
class AboutService
  def initialize(wikipedia)
    @wikipedia = wikipedia
  end

  # The SummaryModel of +game+, or why not: :no_article (Wikidata knows no
  # English article for it, or Wikipedia has none), :unavailable
  # (Wikipedia did not answer). A summary read is the :game event.
  def summary(game)
    return :no_article unless game.article

    found = @wikipedia.summary(game.article)
    return :no_article if found == :missing

    Rubbs.achieve(:game, ref: game.id.to_s, title: game.title.to_s)
    found
  rescue Rubbs::Common::Web::HTTP::Error => e
    Rubbs.log('wikipedia', "#{game.article}: #{e.message}")
    :unavailable
  end
end
