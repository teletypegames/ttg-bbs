# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'cgi'

# Reads Wikipedia through its Action API: a full-text search, and an article
# as plain text cut into its sections. Wikipedia asks every client to name
# itself in the User-Agent, else it may answer 403.
class Wikipedia
  USER_AGENT = 'WikiProxy/0.1 (Teletype Games telnet BBS; https://git.teletypegames.org/bbs/wikiproxy)'
  TTL = 600
  SEARCH_LIMIT = 30

  Result  = Struct.new(:title, :snippet, :words, keyword_init: true)
  Section = Struct.new(:title, :markdown, keyword_init: true)
  Article = Struct.new(:title, :url, :lang, :sections, :redirected_from, keyword_init: true)

  # The sections nobody reads on a terminal: the plain text keeps only
  # their headings.
  SKIP = ['see also', 'references', 'notes', 'footnotes', 'sources', 'external links', 'further reading',
          'bibliography', 'jegyzetek', 'források', 'forrás', 'kapcsolódó szócikkek', 'további információk',
          'irodalom', 'külső hivatkozások', 'siehe auch', 'literatur', 'weblinks', 'einzelnachweise',
          'anmerkungen'].freeze

  # The TeX of a formula as plain text: its symbols, its functions.
  TEX = {
    'alpha' => 'α', 'beta' => 'β', 'gamma' => 'γ', 'Gamma' => 'Γ', 'delta' => 'δ', 'Delta' => 'Δ',
    'epsilon' => 'ε', 'varepsilon' => 'ε', 'theta' => 'θ', 'lambda' => 'λ', 'mu' => 'μ', 'pi' => 'π',
    'rho' => 'ρ', 'sigma' => 'σ', 'Sigma' => 'Σ', 'tau' => 'τ', 'phi' => 'φ', 'varphi' => 'φ', 'Phi' => 'Φ',
    'omega' => 'ω', 'Omega' => 'Ω', 'infty' => '∞', 'cdot' => '·', 'times' => '×', 'pm' => '±', 'div' => '÷',
    'le' => '≤', 'leq' => '≤', 'ge' => '≥', 'geq' => '≥', 'ne' => '≠', 'neq' => '≠', 'approx' => '≈',
    'equiv' => '≡', 'to' => '→', 'rightarrow' => '→', 'Rightarrow' => '⇒', 'in' => '∈', 'sum' => 'Σ',
    'prod' => 'Π', 'int' => '∫', 'partial' => '∂', 'nabla' => '∇', 'ldots' => '…', 'cdots' => '…', 'dots' => '…'
  }.freeze
  FUNCTIONS = %w[sin cos tan cot log ln exp lim max min det arg sinh cosh tanh].freeze

  attr_reader :languages

  def initialize(languages: %w[en hu])
    @languages = languages
    @cache     = {}
    @mu        = Mutex.new
  end

  # The search results for +query+, best first; nil when Wikipedia did not answer.
  def search(query, lang:)
    query = query.to_s.strip
    return [] if query.empty?

    cached([:search, lang, query.downcase]) do
      data = api(lang, action: 'query', list: 'search', srsearch: query, srlimit: SEARCH_LIMIT, srprop: 'snippet|wordcount')
      (data.dig('query', 'search') || []).map do |r|
        Result.new(title: r['title'], snippet: plain(r['snippet']), words: r['wordcount'].to_i)
      end
    end
  rescue StandardError => e
    warn "Wikipedia search error: #{e.class}: #{e.message}"
    nil
  end

  # The article titled +title+ (redirects followed); nil when it is missing
  # or Wikipedia did not answer.
  def article(title, lang:)
    cached([:article, lang, title]) do
      data = api(lang, action: 'query', prop: 'extracts|info', explaintext: 1, exsectionformat: 'wiki',
                       redirects: 1, inprop: 'url', titles: title)
      page = data.dig('query', 'pages', 0)
      next nil if page.nil? || page['missing'] || page['invalid'] || page['extract'].to_s.strip.empty?

      Article.new(title: page['title'], url: page['fullurl'], lang: lang,
                  sections: sections(page['title'], page['extract']),
                  redirected_from: data.dig('query', 'redirects', 0, 'from'))
    end
  rescue StandardError => e
    warn "Wikipedia article error: #{e.class}: #{e.message}"
    nil
  end

  # A random article's title.
  def random(lang:)
    data = api(lang, action: 'query', list: 'random', rnnamespace: 0, rnlimit: 1)
    data.dig('query', 'random', 0, 'title')
  rescue StandardError => e
    warn "Wikipedia random error: #{e.class}: #{e.message}"
    nil
  end

  # What a caller typed: the article of that title (or the one it redirects
  # to) when there is one, else the search results.
  def look_up(query, lang:)
    found = article(query.to_s.strip, lang: lang) unless query.to_s.strip.empty?
    found ? [found, nil] : [nil, search(query, lang: lang)]
  end

  def next_language(lang) = @languages[(@languages.index(lang).to_i + 1) % @languages.size]

  private

  def api(lang, **params)
    raise ArgumentError, "unknown language #{lang}" unless @languages.include?(lang)

    uri = URI("https://#{lang}.wikipedia.org/w/api.php")
    uri.query = URI.encode_www_form(params.merge(format: 'json', formatversion: 2))
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.open_timeout = 10
    http.read_timeout = 15
    response = http.get(uri.request_uri, 'User-Agent' => USER_AGENT, 'Accept-Encoding' => 'identity')
    raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def cached(key)
    hit = @mu.synchronize { @cache[key] }
    return hit[1] if hit && Time.now - hit[0] < TTL

    value = yield
    @mu.synchronize do
      @cache.shift while @cache.size >= 200
      @cache[key] = [Time.now, value]
    end
    value
  end

  # The plain extract cut at its == level-2 == headings; the deeper ones stay
  # in their section as Markdown headings. The lead is named after the article.
  def sections(title, extract)
    parts = [[title, []]]
    formulas(extract.to_s).each_line(chomp: true) do |line|
      if (m = line.match(/\A(={2,6})\s*(.*?)\s*=+\s*\z/))
        if m[1].size == 2
          parts << [m[2], []]
        else
          parts.last[1] << "#{'#' * (m[1].size - 1)} #{m[2]}"
        end
      else
        parts.last[1] << line
      end
    end
    parts.filter_map do |name, lines|
      next if SKIP.include?(name.downcase)

      text = markdown(lines)
      Section.new(title: name, markdown: text) unless text.empty?
    end
  end

  # One paragraph a line in the extract, a blank line between them in
  # Markdown. A heading with nothing under it before the next one of its
  # level goes; a line the renderer would take for a heading, a code fence
  # or a quote is escaped.
  def markdown(lines)
    out = []
    lines.each do |line|
      line = line.gsub(/[ \t]{2,}/, ' ').strip
      next if line.empty?

      if (level = heading_level(line))
        out.pop while heading_level(out.last.to_s).to_i >= level
        out << line
      else
        out << escape(line)
      end
    end
    out.pop while heading_level(out.last.to_s)
    out.join("\n\n")
  end

  def heading_level(line) = line[/\A(#+) /, 1]&.size

  def escape(line) = line.match?(/\A(?:#|```|>)/) ? "\\#{line}" : line

  # A formula comes in the plain text as its MathML, one token a line, and
  # then its TeX; it is put back in its line as the TeX, made readable.
  def formulas(text)
    text = text.gsub(/\n[ \t]+\n(?:[ \t]*[^\n]*\n)*?[ \t]*\{\\displaystyle ?([^\n]*)\}[ \t]*\n(?:[ \t]*\n)?/) do
      " #{tex(::Regexp.last_match(1))} "
    end.gsub(/ +(?=[,.;:)])/, '')
    text.gsub(/\{\\displaystyle ?([^\n]*?)\}(?=\s|\z)/) { tex(::Regexp.last_match(1)) }
  end

  def tex(source)
    s = source.dup
    nil while s.gsub!(/\\[dt]?frac\{([^{}]*)\}\{([^{}]*)\}/, '(\1)/(\2)')
    nil while s.gsub!(/\\sqrt\{([^{}]*)\}/, '√(\1)')
    s = s.gsub(/\\([A-Za-z]+)/) do
      name = ::Regexp.last_match(1)
      TEX[name] || (FUNCTIONS.include?(name) ? " #{name} " : '')
    end
    s = s.gsub(/\\[,;:! ]/, ' ').gsub(/\s+([)}])/, '\1').gsub(/([_^])\{([^{}]{2,})\}/, '\1(\2)').delete('{}\\')
    s.gsub(/\s+/, ' ').strip
  end

  def plain(html) = CGI.unescapeHTML(html.to_s.gsub(/<[^>]*>/, '')).gsub(/\s+/, ' ').strip
end
