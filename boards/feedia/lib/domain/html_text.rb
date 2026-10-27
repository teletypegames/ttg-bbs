# frozen_string_literal: true

require 'cgi'

# The HTML of a feed item as Markdown a terminal can render: paragraphs,
# headings, lists and quotes kept, everything else made plain text. A link
# keeps its text and gets a number, its address listed under the text, the
# way lynx does it; an image keeps its alt text. Control characters go, so
# a feed cannot send escape sequences down the line.
module HtmlText
  ENTITIES = {
    'nbsp' => ' ', 'hellip' => '…', 'ndash' => '–', 'mdash' => '—', 'lsquo' => '‘', 'rsquo' => '’',
    'sbquo' => '‚', 'ldquo' => '“', 'rdquo' => '”', 'bdquo' => '„', 'laquo' => '«', 'raquo' => '»',
    'bull' => '•', 'middot' => '·', 'copy' => '©', 'reg' => '®', 'trade' => '™', 'euro' => '€',
    'pound' => '£', 'deg' => '°', 'times' => '×', 'shy' => '', 'zwnj' => '', 'zwj' => '',
    'odblac' => 'ő', 'Odblac' => 'Ő', 'udblac' => 'ű', 'Udblac' => 'Ű', 'szlig' => 'ß'
  }.merge(
    { 'acute' => "\u0301", 'grave' => "\u0300", 'uml' => "\u0308", 'circ' => "\u0302", 'tilde' => "\u0303",
      'cedil' => "\u0327", 'ring' => "\u030A" }.flat_map do |mark, combining|
      ('a'..'z').to_a.concat(('A'..'Z').to_a).filter_map do |letter|
        composed = (letter + combining).unicode_normalize(:nfc)
        ["#{letter}#{mark}", composed] if composed.length == 1
      end
    end.to_h
  ).freeze

  BLOCK   = %r{</?(?:p|div|section|article|aside|figure|figcaption|table|tr|ul|ol|dl|dt|dd|header|footer|pre|hr)\b[^>]*>}i
  MARK    = "\u0001"
  CONTROL = /[\u0000-\u0008\u000B-\u001F\u007F-\u009F\u200E\u200F\u202A-\u202E\u2066-\u2069]/

  module_function

  def markdown(html)
    links = []
    s = clean(html)
    s.gsub!(%r{<(script|style|iframe|noscript|svg)\b.*?</\1>}im, '')
    s.gsub!(/<!--.*?-->/m, '')
    s.gsub!(/<!\[CDATA\[(.*?)\]\]>/m, '\1')
    s.gsub!(%r{<h[1-6]\b[^>]*>(.*?)</h[1-6]>}im) { "\n\n#{MARK}H#{flat(Regexp.last_match(1))}\n\n" }
    s.gsub!(%r{<blockquote\b[^>]*>(.*?)</blockquote>}im) do
      paragraphs(Regexp.last_match(1)).map { |p| "\n\n#{MARK}Q#{flat(p)}" }.join << "\n\n"
    end
    s.gsub!(/<li\b[^>]*>/i, "\n\n#{MARK}L")
    s.gsub!(%r{<a\b([^>]*)>(.*?)</a>}im) do
      inner = Regexp.last_match(2)
      href  = decode(Regexp.last_match(1)[/\bhref\s*=\s*["']([^"']+)["']/i, 1].to_s).strip
      next inner unless href.match?(%r{\Ahttps?://}i) && !flat(inner).empty?

      links << href unless links.include?(href)
      "#{inner}[#{links.index(href) + 1}]"
    end
    s.gsub!(/<img\b[^>]*>/i) { |tag| (alt = tag[/\balt\s*=\s*"([^"]+)"/i, 1]) ? " [#{alt}] " : ' ' }
    s.gsub!(%r{<br\s*/?>}i, "\n\n")
    blocks = paragraphs(s).filter_map do |p|
      text = flat(p)
      next if text.empty? || text == MARK

      case text
      when /\A#{MARK}H(.*)/o then "### #{Regexp.last_match(1).strip}"
      when /\A#{MARK}Q(.*)/o then "> #{escape(Regexp.last_match(1).strip)}"
      when /\A#{MARK}L(.*)/o then "- #{escape(Regexp.last_match(1).strip)}"
      else escape(text)
      end
    end
    blocks = blocks.grep_v(/\A(?:###|>|-)\s*\z/)
    blocks << "### Links\n\n#{links.each_with_index.map { |l, i| "\\[#{i + 1}] #{clean(l)}" }.join("\n\n")}" if links.any?
    blocks.join("\n\n")
  end

  # Text with no markup at all: titles, names, a feed's description.
  def plain(html) = clean(decode(html.to_s.gsub(/<[^>]*>/, ' '))).gsub(/\s+/, ' ').strip

  def paragraphs(html) = html.gsub(BLOCK, "\n\n").split(/\n\s*\n/)

  def flat(html) = decode(html.gsub(/<[^>]*>/, '')).gsub(/[ \t\r\n]+/, ' ').strip

  def decode(text)
    text.gsub(/&(#x[0-9a-f]+|#\d+|[a-z][a-z0-9]*);/i) do
      ref = Regexp.last_match(1)
      if ref.start_with?('#')
        code = ref[1].casecmp?('x') ? ref[2..].to_i(16) : ref[1..].to_i
        char = code.between?(1, 0x10FFFF) && !code.between?(0xD800, 0xDFFF) ? [code].pack('U') : ''
        char.match?(CONTROL) ? '' : char
      else
        ENTITIES[ref] || CGI.unescapeHTML("&#{ref};")
      end
    end
  end

  def clean(text) = text.to_s.dup.force_encoding(Encoding::UTF_8).scrub('').tr("\t", ' ').gsub(CONTROL, '')

  def escape(line) = line.match?(/\A(?:#|```|>|[-*+] |\d+[.)] )/) ? "\\#{line}" : line
end
