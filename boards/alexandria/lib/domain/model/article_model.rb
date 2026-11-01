# frozen_string_literal: true

# An article as a terminal shows it: the title it was found under, its
# address, the Wikipedia it came from, its sections (SectionModel, the lead
# first) and the title it was redirected from, if any. Wikipedia's text is
# cleaned of control characters on the way in.
ArticleModel = Data.define(:title, :url, :lang, :sections, :redirected_from) do
  # The article in an Action API answer of prop=extracts|info (formatversion
  # 2), or nil when the page is missing, invalid or has no text.
  def self.from_api(data, lang:)
    page = data.dig('query', 'pages', 0)
    return nil if page.nil? || page['missing'] || page['invalid'] || page['extract'].to_s.strip.empty?

    title = line(page['title'])
    new(title: title, url: line(page['fullurl']), lang: lang,
        sections: sections(title, BBS::Text.clean(page['extract'])),
        redirected_from: data.dig('query', 'redirects', 0, 'from')&.then { |from| line(from) })
  end

  def self.sections(title, extract)
    ExtractText.sections(title, extract).map { |name, text| SectionModel.new(name, text) }
  end

  def self.line(text) = BBS::Text.clean(text.to_s, keep_newlines: false)
end
