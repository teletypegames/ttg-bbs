# frozen_string_literal: true

require 'cgi'
require 'bbs/text'

# The model side's text helper, pure functions with no I/O: the HTML of a
# feed item as Markdown a terminal can render, paragraphs, headings, lists
# and quotes kept, everything else made plain text. A link keeps its text
# and gets a number, its address listed under the text, the way lynx does
# it; an image keeps its alt text. Control characters go (BBS::Text.clean),
# so a feed cannot send escape sequences down the line.
module HtmlText
  ENTITIES = {
    'nbsp'   => ' ',
    'hellip' => '…',
    'ndash'  => '–',
    'mdash'  => '—',
    'lsquo'  => '‘',
    'rsquo'  => '’',
    'sbquo'  => '‚',
    'ldquo'  => '“',
    'rdquo'  => '”',
    'bdquo'  => '„',
    'laquo'  => '«',
    'raquo'  => '»',
    'bull'   => '•',
    'middot' => '·',
    'copy'   => '©',
    'reg'    => '®',
    'trade'  => '™',
    'euro'   => '€',
    'pound'  => '£',
    'deg'    => '°',
    'times'  => '×',
    'shy'    => '',
    'zwnj'   => '',
    'zwj'    => '',
    'odblac' => 'ő',
    'Odblac' => 'Ő',
    'udblac' => 'ű',
    'Udblac' => 'Ű',
    'szlig'  => 'ß'
  }.merge(
    {
      'acute' => "\u0301",
      'grave' => "\u0300",
      'uml'   => "\u0308",
      'circ'  => "\u0302",
      'tilde' => "\u0303",
      'cedil' => "\u0327",
      'ring'  => "\u030A"
    }.flat_map do |mark, combining|
      ('a'..'z').to_a.concat(('A'..'Z').to_a).filter_map do |letter|
        composed = (letter + combining).unicode_normalize(:nfc)
        ["#{letter}#{mark}", composed] if composed.length == 1
      end
    end.to_h
  ).freeze

  BLOCK   = %r{</?(?:p|div|section|article|aside|figure|figcaption|table|tr|ul|ol|dl|dt|dd|header|footer|pre|hr)\b[^>]*>}i
  HIDDEN  = %r{<(script|style|iframe|noscript|svg)\b.*?</\1>}im
  MARK    = "\u0001"
  # A paragraph that is only the Markdown sign of an empty heading, quote or item.
  BARE    = /\A(?:###|>|-)\s*\z/

  module_function

  # The HTML of an item as Markdown, its links listed under it.
  def markdown(html)
    links  = []
    blocks = paragraphs(tagged(html, links)).filter_map { |p| block(flat(p)) }.grep_v(BARE)
    blocks << link_list(links) if links.any?
    blocks.join("\n\n")
  end

  # Text with no markup at all: titles, names, a feed's description.
  def plain(html) = clean(decode(html.to_s.gsub(/<[^>]*>/, ' '))).gsub(/\s+/, ' ').strip

  # The HTML with headings, quotes and list items as paragraphs tagged with
  # MARK, its links numbered (their addresses collected in +links+) and its
  # images as their alt text.
  def tagged(html, links)
    s = visible(clean(html))
    s.gsub!(%r{<h[1-6]\b[^>]*>(.*?)</h[1-6]>}im) { "\n\n#{MARK}H#{flat(Regexp.last_match(1))}\n\n" }
    s.gsub!(%r{<blockquote\b[^>]*>(.*?)</blockquote>}im) { quote(Regexp.last_match(1)) }
    s.gsub!(/<li\b[^>]*>/i, "\n\n#{MARK}L")
    s.gsub!(%r{<a\b([^>]*)>(.*?)</a>}im) { anchor(Regexp.last_match(1), Regexp.last_match(2), links) }
    s.gsub!(/<img\b[^>]*>/i) { |tag| (alt = tag[/\balt\s*=\s*"([^"]+)"/i, 1]) ? " [#{alt}] " : ' ' }
    s.gsub(%r{<br\s*/?>}i, "\n\n")
  end

  # The HTML without what a reader never sees: scripts, styles, comments.
  def visible(html) = html.gsub(HIDDEN, '').gsub(/<!--.*?-->/m, '').gsub(/<!\[CDATA\[(.*?)\]\]>/m, '\1')

  def quote(html) = "#{paragraphs(html).map { |p| "\n\n#{MARK}Q#{flat(p)}" }.join}\n\n"

  # A link's text with its number, or the bare text for a link that goes
  # nowhere a reader could follow.
  def anchor(attributes, inner, links)
    href = decode(attributes[/\bhref\s*=\s*["']([^"']+)["']/i, 1].to_s).strip
    return inner unless href.match?(%r{\Ahttps?://}i) && !flat(inner).empty?

    links << href unless links.include?(href)
    "#{inner}[#{links.index(href) + 1}]"
  end

  # One paragraph as a Markdown block; nil for an empty one.
  def block(text)
    return if text.empty? || text == MARK

    case text
    when /\A#{MARK}H(.*)/o then "### #{Regexp.last_match(1).strip}"
    when /\A#{MARK}Q(.*)/o then "> #{escape(Regexp.last_match(1).strip)}"
    when /\A#{MARK}L(.*)/o then "- #{escape(Regexp.last_match(1).strip)}"
    else escape(text)
    end
  end

  def link_list(links)
    "### Links\n\n#{links.each_with_index.map { |l, i| "\\[#{i + 1}] #{BBS::Text.clean(l, keep_newlines: false)}" }.join("\n\n")}"
  end

  def paragraphs(html) = html.gsub(BLOCK, "\n\n").split(/\n\s*\n/)

  def flat(html) = decode(html.gsub(/<[^>]*>/, '')).gsub(/[ \t\r\n]+/, ' ').strip

  def decode(text)
    text.gsub(/&(#x[0-9a-f]+|#\d+|[a-z][a-z0-9]*);/i) do
      ref = Regexp.last_match(1)
      ref.start_with?('#') ? character(ref) : ENTITIES[ref] || CGI.unescapeHTML("&#{ref};")
    end
  end

  # The character of a numeric reference (+#233+, +#xE9+); '' for one that
  # is not a character or is a control character.
  def character(ref)
    code = ref[1].casecmp?('x') ? ref[2..].to_i(16) : ref[1..].to_i
    return '' unless code.between?(1, 0x10FFFF) && !code.between?(0xD800, 0xDFFF)

    BBS::Text.clean([code].pack('U'))
  end

  # Valid UTF-8 without control characters, a tab as a space.
  def clean(text) = BBS::Text.clean(text).tr("\t", ' ')

  def escape(line) = line.match?(/\A(?:#|```|>|[-*+] |\d+[.)] )/) ? "\\#{line}" : line
end
