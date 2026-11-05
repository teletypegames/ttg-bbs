# frozen_string_literal: true

# One hit of a Memory Alpha search: the title and the article's word count.
SearchResultModel = Data.define(:title, :words) do
  def self.from_api(hit) = new(title: Rubbs::Common::Text.line(hit['title']), words: hit['wordcount'].to_i)
end
