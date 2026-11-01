# frozen_string_literal: true

# An article as a terminal shows it: the title it was found under, its
# address, the Wikipedia it came from, its sections (SectionModel, the lead
# first) and the title it was redirected from, if any.
ArticleModel = Data.define(:title, :url, :lang, :sections, :redirected_from) do
  # The article in an Action API answer of prop=extracts|info (formatversion
  # 2), or nil when the page is missing, invalid or has no text.
  def self.from_api(data, lang:)
    page = data.dig('query', 'pages', 0)
    return nil if page.nil? || page['missing'] || page['invalid'] || page['extract'].to_s.strip.empty?

    new(title: page['title'], url: page['fullurl'], lang: lang,
        sections: ExtractText.sections(page['title'], page['extract']).map { |name, text| SectionModel.new(name, text) },
        redirected_from: data.dig('query', 'redirects', 0, 'from'))
  end
end
