# frozen_string_literal: true

require 'cgi'

# One hit of a Wikipedia search: the title, the matching snippet as plain
# text and the article's word count, cleaned of control characters.
SearchResultModel = Data.define(:title, :snippet, :words) do
  # A hit of the Action API's list=search.
  def self.from_api(hit)
    new(title: BBS::Text.clean(hit['title'].to_s, keep_newlines: false), snippet: plain(hit['snippet']),
        words: hit['wordcount'].to_i)
  end

  def self.plain(html)
    text = CGI.unescapeHTML(html.to_s.gsub(/<[^>]*>/, ''))
    BBS::Text.clean(text, keep_newlines: false).gsub(/\s+/, ' ').strip
  end
end
