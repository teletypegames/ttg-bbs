# frozen_string_literal: true

module UI
  # What both faces say about an episode or a series, as [label, value]
  # rows; each face draws them in its own colours.
  module Card
    NOTE = 'From Memory Alpha (memory-alpha.fandom.com), under CC BY-NC; the catalog from Wikidata (CC0).'

    module_function

    def episode(episode, series)
      rows = [['Series', series&.title], [episode.season ? 'Episode' : 'Film', episode.code.empty? ? nil : episode.code],
              ['First aired', episode.aired&.strftime('%Y-%m-%d')], ['Directed by', list(episode.directors)],
              ['Written by', list(episode.writers)], ['Memory Alpha', episode.ma || '(searched by its title)']]
      rows.reject { |_, value| value.to_s.empty? }
    end

    def series(series, episodes, seasons)
      count = series.films? ? "#{episodes.size} films" : "#{episodes.size} episodes in #{seasons.size} seasons"
      [['Years', series.years], ['In the catalog', count], ['Memory Alpha', series.ma]].reject { |_, v| v.to_s.empty? }
    end

    def list(names) = names.empty? ? nil : names.first(4).join(', ')
  end
end
