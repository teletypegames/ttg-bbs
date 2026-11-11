# frozen_string_literal: true

# A Wikipedia article as a terminal shows it: its language, title, address
# and page id, and its sections (SectionModel, the lead first). The text is
# cleaned of control characters on the way in.
ArticleModel = Data.define(:language, :title, :url, :pageid, :sections) do
  # The article in an Action API answer of prop=extracts|info (formatversion
  # 2), or nil when the page is missing, invalid or has no text.
  def self.from_api(language, data)
    page = data.dig('query', 'pages', 0)
    return nil if page.nil? || page['missing'] || page['invalid'] || page['extract'].to_s.strip.empty?

    title = Rubbs::Common::Text.line(page['title'])
    new(
      language: language,
      title:    title,
      url:      Rubbs::Common::Text.line(page['fullurl']),
      pageid:   page['pageid'].is_a?(Integer) ? page['pageid'] : nil,
      sections: sections(title, Rubbs::Common::Text.clean(page['extract']))
    )
  end

  def self.sections(title, extract)
    Rubbs::Common::Web::MediaWiki::Extract.sections(title, extract, skip: ArticleModel::SKIP)
      .map { |name, text| SectionModel.new(name, text) }
  end

  # The shortest address of the article, for a QR code: by its page id.
  def short_url = pageid ? "https://#{language}.wikipedia.org/?curid=#{pageid}" : url

  def license = "Wikipedia (#{language}), CC BY-SA 4.0"
end

# One section of an article: its heading and its text in Markdown.
SectionModel = Data.define(:title, :markdown)

class ArticleModel
  # The sections a terminal leaves out: the links, the lists of sources.
  SKIP = ['external links', 'references', 'notes', 'footnotes', 'see also', 'further reading', 'bibliography',
          'sources', 'források', 'jegyzetek', 'további információk', 'kapcsolódó szócikkek', 'irodalom'].freeze
end
