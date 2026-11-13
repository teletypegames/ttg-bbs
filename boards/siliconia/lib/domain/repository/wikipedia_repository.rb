# frozen_string_literal: true

require 'json'

# The lead of an English or Hungarian Wikipedia article as plain text, through the Action
# API's extracts (rubbs' Rubbs::Common::Web::Wikipedia, five requests a second). The
# answers are kept for TTL seconds in a Rubbs::Common::Storage::Cache bounded in entries and in
# bytes (of their JSON); the text is cleaned of control characters. A
# failure goes up as Rubbs::Common::Web::HTTP::Error.
class WikipediaRepository
  USER_AGENT  = 'SiliconiaBBS/0.1 (Siliconia BBS, Teletype Games telnet BBS; https://teletypegames.org; ' \
                'https://git.teletypegames.org/bbs/ttg-bbs/src/branch/master/boards/siliconia)'
  TTL         = 86_400
  CACHE_BYTES = 4 * 1024 * 1024
  # A lead longer than this many characters is cut at a paragraph.
  MAX_TEXT    = 6000
  RATE        = 5

  def initialize(cache_size: 200, client: Rubbs::Common::Web::Wikipedia.new(user_agent: USER_AGENT, rate: RATE))
    @client  = client
    @answers = Rubbs::Common::Storage::Cache.new(
      ttl:         TTL,
      max_entries: cache_size,
      max_bytes:   CACHE_BYTES,
      size:        ->(data) { JSON.generate(data).bytesize }
    )
  end

  # The SummaryModel of the article +title+ of the Wikipedia in +language+ ('en' or 'hu',
  # redirects followed); :missing when there is no such article.
  def summary(title, language = 'en')
    summary_of(@answers.fetch([language, title]) { lead(title, language) }, language)
  end

  private

  def lead(title, language)
    @client.get(
      language,
      action:      'query',
      prop:        'extracts|info',
      exintro:     1,
      explaintext: 1,
      redirects:   1,
      inprop:      'url',
      titles:      title
    )
  end

  def summary_of(data, language)
    page = data.dig('query', 'pages', 0)
    text = page && Rubbs::Common::Text.clean(page['extract'].to_s).strip
    return :missing if page.nil? || page['missing'] || page['invalid'] || text.empty?

    SummaryModel.new(
      title:      line(page['title']),
      url:        line(page['fullurl']),
      paragraphs: paragraphs(text).freeze,
      language:   language
    )
  end

  def paragraphs(text)
    out = []
    text.split(/\n+/).map { |p| p.gsub(/\s+/, ' ').strip }.reject(&:empty?).each do |p|
      break if out.any? && out.sum(&:size) + p.size > MAX_TEXT

      out << p.freeze
    end
    out
  end

  def line(text) = Rubbs::Common::Text.line(text)
end
