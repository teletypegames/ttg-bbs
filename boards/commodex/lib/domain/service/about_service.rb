# frozen_string_literal: true

# What Wikipedia says about a game: the lead of its English article.
class AboutService
  def initialize(wikipedia)
    @wikipedia = wikipedia
  end

  # The SummaryModel of +game+, or why not: :no_article (Wikidata knows no
  # English article for it, or Wikipedia has none), :unavailable
  # (Wikipedia did not answer).
  def summary(game)
    return :no_article unless game.article

    case (found = @wikipedia.summary(game.article))
    when nil      then :unavailable
    when :missing then :no_article
    else found
    end
  end
end
