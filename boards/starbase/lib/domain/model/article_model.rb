# frozen_string_literal: true

# A Memory Alpha article as a terminal shows it: its title, address and
# page id, its sections (SectionModel, the lead first) and the title it was
# redirected from, if any. The text is cleaned of control characters on the
# way in.
ArticleModel = Data.define(:title, :url, :pageid, :sections, :redirected_from) do
  # The article in an Action API answer of prop=extracts|info (formatversion
  # 2), or nil when the page is missing, invalid or has no text.
  def self.from_api(data)
    page = data.dig('query', 'pages', 0)
    return nil if page.nil? || page['missing'] || page['invalid'] || page['extract'].to_s.strip.empty?

    title = Rubbs::Common::Text.line(page['title'])
    new(
      title:           title,
      url:             Rubbs::Common::Text.line(page['fullurl']),
      pageid:          page['pageid'].is_a?(Integer) ? page['pageid'] : nil,
      sections:        sections(title, Rubbs::Common::Text.clean(page['extract'])),
      redirected_from: data.dig('query', 'redirects', 0, 'from')&.then { |from| Rubbs::Common::Text.line(from) }
    )
  end

  def self.sections(title, extract)
    Rubbs::Common::Web::MediaWiki::Extract.sections(title, extract, skip: ArticleModel::SKIP).map { |name, text| SectionModel.new(name, text) }
  end

  # The shortest address of the article, for a QR code: by its page id
  # (<tt>?curid=</tt>), which stays short whatever the title.
  def short_url = pageid ? "#{ArticleModel::SITE}/?curid=#{pageid}" : url
end

class ArticleModel
  # The address of Memory Alpha.
  SITE = 'https://memory-alpha.fandom.com'
  # The sections a terminal leaves out: the links and the footnotes.
  SKIP = ['links and references', 'external links', 'references', 'notes', 'footnotes', 'see also'].freeze
end
