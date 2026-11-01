# frozen_string_literal: true

# The lead of an English Wikipedia article as plain text, through the Action
# API's extracts (WikipediaClient, the way Alexandria BBS reads Wikipedia).
# The answers are kept for TTL seconds in a BBS::Cache bounded in entries
# and in bytes; the text is cleaned of control characters.
class WikipediaRepository
  USER_AGENT  = 'CommodexBBS/0.1 (Commodex BBS, Teletype Games telnet BBS; https://teletypegames.org; ' \
                'https://git.teletypegames.org/bbs/commodex-bbs)'
  TTL         = 86_400
  CACHE_BYTES = 4 * 1024 * 1024
  # A lead longer than this many characters is cut at a paragraph.
  MAX_TEXT    = 6000

  def initialize(cache_size: 200, client: WikipediaClient.new(user_agent: USER_AGENT))
    @client  = client
    @answers = BBS::Cache.new(ttl: TTL, max_entries: cache_size, max_bytes: CACHE_BYTES)
  end

  # The SummaryModel of the article +title+ (redirects followed); :missing
  # when there is no such article, nil when Wikipedia did not answer.
  def summary(title)
    summary_of(JSON.parse(@answers.fetch(title) { lead(title) }))
  rescue StandardError => e
    warn "commodex-bbs: Wikipedia: #{e.class}: #{e.message}"
    nil
  end

  private

  def lead(title)
    @client.get('en', action: 'query', prop: 'extracts|info', exintro: 1, explaintext: 1, redirects: 1,
                      inprop: 'url', titles: title)
  end

  def summary_of(data)
    page = data.dig('query', 'pages', 0)
    text = page && BBS::Text.clean(page['extract'].to_s).strip
    return :missing if page.nil? || page['missing'] || page['invalid'] || text.empty?

    SummaryModel.new(title: line(page['title']), url: line(page['fullurl']), paragraphs: paragraphs(text).freeze)
  end

  def paragraphs(text)
    out = []
    text.split(/\n+/).map { |p| p.gsub(/\s+/, ' ').strip }.reject(&:empty?).each do |p|
      break if out.any? && out.sum(&:size) + p.size > MAX_TEXT

      out << p.freeze
    end
    out
  end

  def line(text) = BBS::Text.clean(text.to_s, keep_newlines: false)
end
