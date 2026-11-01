# frozen_string_literal: true

require 'cgi'

# One hit of a Wikipedia search: the title, the matching snippet as plain
# text and the article's word count.
SearchResultModel = Data.define(:title, :snippet, :words) do
  # A hit of the Action API's list=search.
  def self.from_api(hit)
    new(title: hit['title'], snippet: plain(hit['snippet']), words: hit['wordcount'].to_i)
  end

  def self.plain(html) = CGI.unescapeHTML(html.to_s.gsub(/<[^>]*>/, '')).gsub(/\s+/, ' ').strip
end
